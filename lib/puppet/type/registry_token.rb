require 'securerandom'
require 'time'

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

    def normalize_name(name)
      provider.normalize_project_name(name)
    end

    def normalize_scope(scope)
      provider.normalize_project_scope(scope)
    end

    def check_name(name)
      name.is_a?(String) && normalize_name(name).split('/').all? { |x| x =~ %r{^[a-z0-9]+((?:[._]|__|[-]*)[a-z0-9]+)*$} }
    end

    def check_scope(scope)
      return false unless scope.is_a?(Hash)

      s = scope.map { |k, v| [k.to_s, v] }.to_h
      actions = s['actions']
      name    = s['name']
      type    = s['type']

      return false unless name

      if type
        return false unless type.to_s == 'repository'
      end

      if actions
        a = [actions].flatten.map { |x| x.to_s }

        return false unless a.all? { |x| ['*', 'delete', 'pull', 'push'].include?(x) }
      end

      check_name(name)
    end

    def sort_scope(scope)
      [scope].flatten.compact.sort_by { |a| a['name'] }
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
