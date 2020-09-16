require 'time'
require 'openssl'

Puppet::Type.type(:registry_token).provide(:ruby) do
  @doc = 'Registry auth token provider'

  confine :exists => '/opt/gitlab/embedded/service/gitlab-rails/lib/json_web_token/token.rb'
  confine :exists => '/opt/gitlab/embedded/service/gitlab-rails/lib/json_web_token/rsa_token.rb'
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

    @instances << new(name: entity_name,
                      ensure: :present,
                      id: entity['jti'],
                      audience: entity['aud'],
                      subject: entity['sub'],
                      issuer: entity['iss'],
                      issued_at: entity['iat'].to_i,
                      not_before: entity['nbf'].to_i,
                      expire_time: entity['exp'].to_i,
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

  def self.token_decrypt(token)
    pkey = File.read(REGISTRY_KEY)
    secret = OpenSSL::PKey::RSA.new(pkey).public_key

    JWT.decode(token, secret, true, algorithm: 'RS256')
  rescue OpenSSL::PKey::RSAError => e
    Puppet.warning(_('Can not create RSA PKey object (%{message})') % { message: e.message })
    return []
  rescue SystemCallError # Errno::ENOENT
    return []
  end

  def self.token_content(file_name)
    return '' unless File.exist?(file_name)
    File.read(file_name)
  end

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

  def authorized_token
    require '/opt/gitlab/embedded/service/gitlab-rails/lib/json_web_token/token.rb'
    require '/opt/gitlab/embedded/service/gitlab-rails/lib/json_web_token/rsa_token.rb'

    JSONWebToken::RSAToken.new(REGISTRY_KEY).tap do |token|
      token.issuer      = @resource[:issuer]
      token.audience    = @resource[:audience]
      token.subject     = @resource[:subject]
      token.expire_time = @resource[:expire_time].to_i
      token[:access] = []
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

  def update_content
    @content = { 'token' => authorized_token.encoded }.to_json
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    update_content
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

  def flush
    return if @property_flush.empty?

    update_content

    @property_flush.clear
  end
end
