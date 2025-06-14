$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))
require 'puppet_x/gitlabinstall/token_tools'
require 'time'
require 'openssl'
require 'json'
require 'base64'
require 'securerandom'

Puppet::Type.type(:registry_token).provide(:ruby) do
  @doc = 'Registry auth token provider'

  confine true: begin
                  require 'jwt'
                  require 'base32'
                rescue LoadError
                  false
                else
                  true
                end

  REGISTRY_KEY = '/var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key'.freeze
  SECRETS_FILE = '/etc/gitlab/gitlab-secrets.json'.freeze

  # This class generates a JWT signed with an RSA private key.
  class RSATokenHelper
    # The signing algorithm to use for all tokens.
    ALGORITHM = 'RS256'
    DEFAULT_NOT_BEFORE_TIME = 5
    DEFAULT_EXPIRE_TIME = 60

    attr_accessor :id, :audience, :subject, :issuer
    attr_accessor :issued_at, :not_before, :expire_time

    # New constructor that accepts key content instead of file path
    def initialize(key_data)
      # Directly set key content to instance variable
      @key_data = key_data

      @id = SecureRandom.uuid
      @issued_at = Time.now
      # we give a few seconds for time shift
      @not_before = issued_at - DEFAULT_NOT_BEFORE_TIME
      # default 60 seconds should be more than enough for this authentication token
      @expire_time = issued_at + DEFAULT_EXPIRE_TIME
      @custom_payload = {}
    end

    def [](key)
      @custom_payload[key]
    end

    def []=(key, value)
      @custom_payload[key] = value
    end

    def payload
      predefined_claims
        .merge(@custom_payload)
        .merge(default_payload)
    end

    # Generates the final, signed JWT string.
    #
    # @return [String] The encoded JWT.
    def encoded
      headers = { kid: kid, typ: 'JWT' }
      JWT.encode(payload, key, ALGORITHM, headers)
    end

    # Decodes and verifies a JWT using a public key.
    #
    # @param token [String] The JWT string to decode.
    # @param public_key [OpenSSL::PKey::RSA] The public key for verification.
    # @return [Array] The decoded payload and header.
    def self.decode(token, public_key)
      options = { algorithm: ALGORITHM }
      JWT.decode(token, public_key, true, options)
    end

    private
    def predefined_claims
      {}
    end

    def default_payload
      {
        jti: id,
        aud: audience,
        sub: subject,
        iss: issuer,
        iat: issued_at.to_i,
        nbf: not_before.to_i,
        exp: expire_time.to_i
      }.compact
    end

    def key_data
      @key_data
    end

    # Creates an OpenSSL RSA key object from the raw key data.
    def key
      @key ||= OpenSSL::PKey::RSA.new(key_data)
    end

    # Extracts the public key from the private key object.
    def public_key
      key.public_key
    end

    # Generates a canonical representation of the JWK for thumbprint calculation.
    #
    # @see https://tools.ietf.org/html/rfc7638 JWK Thumbprint RFC
    #
    # The JWK Thumbprint specification (RFC 7638) requires a key to be
    # "normalized" before it is hashed. This process ensures that a thumbprint
    # is stable and verifiable across different systems and implementations.
    #
    # Normalization achieves two primary goals:
    #   1.  **Strips Non-Essential Data:** It includes *only* the required public
    #       components of the key (e.g., 'kty', 'n', 'e' for an RSA key),
    #       ignoring any private components or other optional parameters.
    #   2.  **Enforces Order:** It orders the keys of the components alphabetically.
    #
    # This guarantees that the exact same cryptographic key will always produce
    # the exact same JSON output, which in turn results in a consistent and
    # predictable thumbprint.
    #
    # @return [Hash] A new hash containing only the alphabetized, essential members of the JWK.
    def normalize_key
      # Get the required public key components (modulus 'n' and exponent 'e').
      # These are OpenSSL::BN (BigNum) objects.
      n = public_key.n
      e = public_key.e

      # canonical representation of the public key in JSON format
      {
        e: Base64.urlsafe_encode64(e.to_s(2), padding: false),
        kty: 'RSA',
        n: Base64.urlsafe_encode64(n.to_s(2), padding: false)
      }
    end

    # Calculates the JWK Thumbprint as per RFC 7638.
    def thumbprint
      # Hash it using SHA-256
      digest = OpenSSL::Digest::SHA256.new

      # Encode hash in Base64url - this is the correct kid
      Base64.urlsafe_encode64(digest.digest(normalize_key.to_json), padding: false)
    end

    # Generates the JWK Thumbprint to use as the Key ID (`kid`).
    def kid
      thumbprint
    end
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  mk_resource_methods

  def self.get_key_data
    # Try to get the key from secrets file
    if File.exist?(SECRETS_FILE)
      begin
        gitlab_secrets = JSON.parse(File.read(SECRETS_FILE))
        key_content = gitlab_secrets&.dig('gitlab_rails', 'openid_connect_signing_key')
        return key_content if key_content
      rescue # Ignore parsing errors and continue
      end
    end

    # If unable to get key from secrets, read and return
    # content of the default path file
    File.read(REGISTRY_KEY)
  end

  def self.normalize_project_scope(scope)
    Puppet_X::GitlabInstall.normalize_project_scope(scope)
  end

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
                      ttl: entity['exp'].to_i - Time.now.to_i,
                      access: normalize_project_scope(entity['access']),
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
    pkey = get_key_data
    secret = OpenSSL::PKey::RSA.new(pkey).public_key

    JWT.decode(token, secret, true, algorithm: 'RS256')
  rescue OpenSSL::PKey::RSAError => e
    Puppet.warning(_('Can not create RSA PKey object (%{message})') % { message: e.message })
    []
  rescue JWT::DecodeError
    []
  rescue SystemCallError # Errno::ENOENT
    []
  end

  def self.prefetch(resources)
    entities = instances
    # rubocop:disable Lint/AssignmentInCondition
    resources.each_key do |entity_name|
      if provider = entities.find { |entity| entity.name == entity_name }
        resources[entity_name].provider = provider
      end
    end
    # rubocop:enable Lint/AssignmentInCondition
  end

  def resource_access
    return nil unless @resource[:access]
    @resource[:access].flatten.compact
  end

  def authorized_token
    # 1. Get key content
    key_data = self.class.get_key_data

    # 2. Create instance of our new helper, passing the key content
    RSATokenHelper.new(key_data).tap do |token|
      token.issuer      = @resource[:issuer]
      token.audience    = @resource[:audience]
      token.subject     = @resource[:subject]
      token.expire_time = expire_time
      token[:access]    = resource_access || []
      token[:jti]       = @resource[:id]
      token[:iat]       = @resource[:issued_at].to_i
      token[:nbf]       = @resource[:not_before].to_i
      token[:auth_type] = 'gitlab_or_ldap'
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
    content['access'] = resource_access

    @content = content.to_json
  end

  def store_content
    File.open(target_path, 'w') { |f| f.write(token_content) }
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
    exp = current + threshold

    (is > exp)
  end

  def expire_time
    # setup expire time concidering TTL
    exp       = @resource[:expire_time].to_i

    ttl       = @resource[:ttl].to_i
    threshold = @resource[:threshold].to_i

    current = Time.now.to_i

    # expiration date is too close
    if current + threshold > exp
      exp = current + ttl
    end

    exp
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
