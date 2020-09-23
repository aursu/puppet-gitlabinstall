require 'time'
require 'openssl'

Puppet::Type.type(:registry_token).provide(:ruby) do
  @doc = 'Registry auth token provider'

  confine exists: '/opt/gitlab/embedded/service/gitlab-rails/lib/json_web_token/token.rb'
  confine exists: '/opt/gitlab/embedded/service/gitlab-rails/lib/json_web_token/rsa_token.rb'
  confine true: begin
                  require 'jwt'
                  require 'base32'
                rescue LoadError
                  false
                else
                  true
                end

  REGISTRY_KEY = '/var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key'.freeze

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  mk_resource_methods

  def self.add_instance(name, entity = {})
    @instances = [] unless @instances

    entity_name = (name == 'token') ? 'default' : name
    entity_access = normalize_project_scope(entity['access']) if entity['access']

    @instances << new(name: entity_name,
                      ensure: :present,
                      id: entity['jti'],
                      audience: entity['aud'],
                      subject: entity['sub'],
                      issuer: entity['iss'],
                      issued_at: entity['iat'].to_i,
                      not_before: entity['nbf'].to_i,
                      expire_time: entity['exp'].to_i,
                      access: entity_access,
                      target: "#{name}.json",
                      provider: name)
  end

  def self.instances
    return @instances if @instances

    Dir.glob('/etc/docker/registry/*.json').each do |file_name|
      instance_name = %r{(?<token_name>[^/]+)\.json$}.match(file_name.downcase)[:token_name]

      entity = token_data(file_name)
      next if entity.empty?

      add_instance(instance_name, entity)
    end

    @instances || []
  end

  def self.normalize_project_name(name)
    name.gsub(%r{^/|/$}, '')
  end

  def self.normalize_project_scope(scope)
    return scope.map { |x| normalize_project_scope(x) } if scope.is_a?(Array)

    s = scope.is_a?(String) ? { 'name' => scope } : scope.map { |k, v| [k.to_s, v] }.to_h

    actions = s['actions']
    name    = s['name']
    type    = s['type']

    s['name']    = normalize_name(name)
    s['type']    = type ? type.to_s : 'repository'
    s['actions'] = actions ? [actions].flatten.map { |a| a.to_s }.sort : ['pull', 'push']

    s
  end

  # read and decrypt token from Token file in /etc/docker/registry directory
  # return token decrypted data
  def self.token_data(file_name)
    content = token_content(file_name)
    return {} if content.empty?

    begin
      data = JSON.parse(content)
    rescue JSON::ParserError
      return {}
    end

    jwt, = token_decrypt(data['token']).select { |j| j['jti'] }

    return {} if jwt.nil?
    jwt
  end

  # read token from token file in /etc/docker/registry directory
  def self.token_content(file_name)
    return '' unless File.exist?(file_name)
    File.read(file_name)
  end

  # decrypt raw token data using registry private key
  def self.token_decrypt(token)
    pkey = File.read(REGISTRY_KEY)
    secret = OpenSSL::PKey::RSA.new(pkey).public_key

    JWT.decode(token, secret, true, algorithm: 'RS256')
  rescue OpenSSL::PKey::RSAError => e
    Puppet.warning(_('Can not create RSA PKey object (%{message})') % { message: e.message })
    return []
  rescue JWT::DecodeError
    return []
  rescue SystemCallError # Errno::ENOENT
    return []
  end

  def self.prefetch(resources)
    entities = instances
    # rubocop:disable Lint/AssignmentInCondition
    resources.keys.each do |entity_name|
      if provider = entities.find { |entity| entity.name == entity_name }
        resources[entity_name].provider = provider
      end
    end
    # rubocop:enable Lint/AssignmentInCondition
  end

  def authorized_token
    require '/opt/gitlab/embedded/service/gitlab-rails/lib/json_web_token/token.rb'
    require '/opt/gitlab/embedded/service/gitlab-rails/lib/json_web_token/rsa_token.rb'

    JSONWebToken::RSAToken.new(REGISTRY_KEY).tap do |token|
      token.issuer      = @resource[:issuer]
      token.audience    = @resource[:audience]
      token.subject     = @resource[:subject]
      token.expire_time = @resource[:expire_time].to_i
      token[:access] = @resource[:access] || []
      token[:jti]    = @resource[:id]
      token[:iat]    = @resource[:issued_at].to_i
      token[:nbf]    = @resource[:not_before].to_i
    end
  end

  def target_path
    target = @resource[:target] || 'token.json'
    "/etc/docker/registry/#{target}"
  end

  def token_data
    return @token if @token

    token = self.class.token_data(target_path)
    @token = if token.empty?
               {}
             else
               token
             end
  end

  def token_content
    @content ||= self.class.token_content(target_path)
  end

  def generate_content
    content = { 'token' => authorized_token.encoded }
    content['access'] = @resource[:access] if @resource[:access]

    @content = content.to_json
  end

  def store_content
    File.open(target_path, 'w') { |f| f.write(token_content) }
  end

  def normalize_project_name(name)
    self.class.normalize_project_name(name)
  end

  def normalize_project_scope(scope)
    self.class.normalize_project_scope(scope)
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def exp_insync?
    is        = @property_hash[:expire_time]
    threshold = @resource[:threshold].to_i

    # not in sync if not set
    return false if is.nil? || is.to_s == 'absent'

    current = Time.now.to_i

    return true if is - current >= threshold
  end

  def destroy
    @property_hash[:ensure] = :absent
  end

  def create
    generate_content
    store_content
  end

  def audience=(aud)
    @property_flush[:audience] = aud
  end

  def subject=(sub)
    @property_flush[:subject] = sub
  end

  def issuer=(iss)
    @property_flush[:issuer] = iss
  end

  def expire_time=(exp)
    @property_flush[:expire_time] = exp
  end

  def access=(acc)
    @property_flush[:access] = acc
  end

  def flush
    return if @property_flush.empty?

    generate_content
    store_content

    @property_flush.clear
  end
end
