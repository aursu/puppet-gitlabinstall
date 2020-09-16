require 'securerandom'
require 'time'

Puppet::Type.newtype(:registry_token) do
  @doc = 'Registry authentication JWT token'

  DEFAULT_NOT_BEFORE_TIME = 5
  DEFAULT_EXPIRE_TIME = 60

  class TimeProperty < Puppet::Property
    validate do |value|
      # accept unix timestamp
      return true if value.to_s =~ %r{^[0-9]{10}$}
      # raise ArgumentError if not time data could be found
      Time.parse(value)
    end

    munge do |value|
      return value.to_i if value.to_s =~ %r{^[0-9]{10}$}
      Time.parse(value).to_i
    end
  end

  ensurable do
    desc 'Create or remove token.'

    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.delete
    end

    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc 'Token Name'
  end

  newparam(:id) do
    desc 'Token ID'

    defaultto do
      SecureRandom.uuid
    end
  end

  newproperty(:audience) do
    desc 'Auth service'

    defaultto 'container_registry'

    def retrieve
      provider.token_data['aud']
    end
  end

  newproperty(:subject) do
    desc 'Token username'

    def retrieve
      provider.token_data['sub']
    end
  end

  newproperty(:issuer) do
    desc 'Token issuer'

    defaultto 'omnibus-gitlab-issuer'

    def retrieve
      provider.token_data['iss']
    end
  end

  newproperty(:issued_at, parent: TimeProperty) do
    desc 'Time when token have been issued at'

    defaultto do
      Time.now.to_i
    end

    def retrieve
      provider.token_data['iat'].to_i
    end
  end

  newproperty(:not_before, parent: TimeProperty) do
    desc 'Time when token starts to be valid'

    defaultto do
      @resource[:issued_at].to_i + DEFAULT_NOT_BEFORE_TIME
    end

    def retrieve
      provider.token_data['nbf'].to_i
    end
  end

  newproperty(:expire_time, parent: TimeProperty) do
    desc 'Token expiration time'

    defaultto do
      @resource[:issued_at].to_i + DEFAULT_EXPIRE_TIME
    end

    def retrieve
      provider.token_data['exp'].to_i
    end
  end

  newparam(:target) do
    desc 'File inside /etc/docker/registry directory where token should be stored'

    defaultto 'token.json'

    newvalues(%r{^[a-z0-9.-]+$})

    munge do |value|
      return value if value =~ %r{\.json$}
      "#{value}.json"
    end
  end

  autobefore(:file) do
    target = self[:target]
    "/etc/docker/registry/#{target}"
  end

  # This will generate additional File[path] resource to setuo permissions
  # or delete token file
  def generate
    target = self[:target]
    path = "/etc/docker/registry/#{target}"

    file_opts = if self[:ensure] == :present
                  {
                    ensure: :file,
                    path: path,
                    owner: 'root',
                    group: 'root',
                    mode: '0600',
                  }
                else
                  {
                    ensure: :absent,
                    path: path,
                  }
                end

    metaparams = Puppet::Type.metaparams
    excluded_metaparams = [:before, :notify, :require, :subscribe, :tag]

    metaparams.reject! { |param| excluded_metaparams.include?(param) }

    metaparams.each do |metaparam|
      file_opts[metaparam] = self[metaparam] unless self[metaparam].nil?
    end

    [Puppet::Type.type(:file).new(file_opts)]
  end

  validate do
    current     = Time.now.to_i
    not_before  = self[:not_before].to_i
    expire_time = self[:expire_time].to_i
    subject     = self[:subject]

    if not_before >= expire_time || current >= expire_time
      raise Puppet::Error, 'Token expiration time is incorrect'
    end

    raise Puppet::Error, 'Username must be provided' unless subject
  end
end
