$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))
require 'puppet_x/gitlabinstall/token_tools'
require 'securerandom'
require 'time'

# Token expiration time
#
# By default if not set explicitly (eg in resource definition
# registry_token { 'name': expire_time => "2020-10-01 22:00" }) it will be set
# to current time (Puppet agent run time) plus default expire time period in
# 1 hour.
#
# If default expire time period less than Threshold than it will be set to
# either Threshold or TTL (which value greater). Default value for Threshold
# is 600 seconds and for TTL si 24 hours
#
# If expiration time is not in sync - all time settinngs will be reset into new
# updated values
#
Puppet::Type.newtype(:registry_token) do
  @doc = 'Registry authentication JWT token'

  DEFAULT_NOT_BEFORE_TIME = 5
  DEFAULT_EXPIRE_TIME = 3600

  # time property base
  class TimeProperty < Puppet::Property
    validate do |value|
      # accept unix timestamp
      return true if value.to_s =~ %r{^[0-9]{10}$}
      # raise TypeError if not time data could be found
      Time.parse(value)
    end

    munge do |value|
      return value.to_i if value.to_s =~ %r{^[0-9]{10}$}
      Time.parse(value).to_i
    end

    def insync?(_is)
      provider.exp_insync?
    end
  end

  ensurable do
    desc 'Create or remove token.'

    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.destroy
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

  newparam(:threshold) do
    desc 'Validity threshold'

    # acceptable expiration period is 10 minutes
    defaultto 600

    munge do |value|
      case value
      when String
        Integer(value)
      else
        value
      end
    end

    validate do |value|
      return true if value.to_s =~ %r{^\d+$}
      raise ArgumentError, _('Threshold must be provided as a number.')
    end
  end

  newproperty(:ttl) do
    desc 'Controls the expiry of the token'

    newvalues(%r{^([0-9]+h)?([1-5]?[0-9]m)?([1-5]?[0-9]s)?$}, %r{^[0-9]+s?$})

    defaultto '24h0m0s'

    validate do |value|
      raise ArgumentError, _('TTL parameter could not be empty') if value.empty?
    end

    munge do |value|
      s = 0
      ttl = 0

      # format XXhXXmXXs in use - return it
      mttl = %r{^(?<hours>[0-9]+h)?(?<mins>[1-5]?[0-9]m)?(?<secs>[1-5]?[0-9]s)?$}.match(value.to_s)
      if mttl
        s   = mttl[:secs].to_i
        ttl = mttl[:hours].to_i * 3600 + mttl[:mins].to_i * 60

        return (ttl + s) if ttl > 0
      end

      mstamp = %r{^(?<secs>[0-9]+s?)?$}.match(value.to_s)
      s = mstamp[:secs].to_i if mstamp && mstamp[:secs].to_i > s

      ttl + s
    end

    def retrieve
      provider.token_data['exp'].to_i - Time.now.to_i
    end

    def insync?(_is)
      provider.exp_insync?
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

  newproperty(:access, array_matching: :all) do
    desc 'Token access levels'

    defaultto :absent

    def retrieve
      provider.token_data['access']
    end

    validate do |value|
      # [ { "type" => "repository", "name" => "group/project", "actions" => ["push", "pull"]}, {}, {} ]
      # { "type" => "repository", "name" => "group/project", "actions" => "*" }
      # { "name" => "group/project", "actions" => ["push", "pull"] }
      # { "name" => "group/project" }
      # "group/project"

      return true if value.to_s == 'absent'

      return value.all? { |s| check_name(s) || check_scope(s) } if value.is_a?(Array)
      return true if check_name(value) || check_scope(value)

      raise ArgumentError, _("Token access field is not correct. Must be in format: { \"type\" => \"repository\", \"name\" => \"group/project\", \"actions\" => [\"pull\", \"push\"]}, not #{value}")
    end

    munge do |value|
      normalize_scope(value)
    end

    def insync?(is)
      sort_scope(is) == sort_scope(should)
    end

    def normalize_scope(scope)
      Puppet_X::GitlabInstall.normalize_project_scope(scope)
    end

    def check_name(name)
      Puppet_X::GitlabInstall.check_project_name(name)
    end

    def check_scope(scope)
      Puppet_X::GitlabInstall.check_project_scope(scope)
    end

    def sort_scope(scope)
      Puppet_X::GitlabInstall.sort_scope(scope)
    end

    def should_to_s(newvalue = @should)
      super(newvalue.compact)
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
    threshold   = self[:threshold].to_i
    subject     = self[:subject]

    if current + threshold > expire_time
      raise Puppet::Error, 'Token expiration is too close. Please update'
    end

    if not_before >= expire_time
      raise Puppet::Error, 'Token start time is incorrect'
    end

    raise Puppet::Error, 'Username must be provided' unless subject
  end
end
