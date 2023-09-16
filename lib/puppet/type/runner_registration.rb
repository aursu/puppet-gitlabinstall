require 'uri'
require 'puppet/parameter/boolean'

# https://gitlab.crylan.com/help/architecture/blueprints/runner_tokens/index.md#using-the-authentication-token-in-place-of-the-registration-token

Puppet::Type.newtype(:runner_registration) do
  @doc = 'GitLab runner registration'

  VALID_GITLAB_SCHEMES = ['http', 'https'].freeze

  # Parrent class for array property
  class ArrayProperty < Puppet::Property
    validate do |value|
      raise ArgumentError, _('Value must be provided as a string.') unless value.is_a?(String)
      raise ArgumentError, _('Value can not be empty') if value.empty?

      status, errmsg = validate_value?(value)
      raise ArgumentError, errmsg unless status
    end

    munge do |value|
      value.to_s
    end

    def insync?(is)
      return (is.sort == @should.sort) if is.is_a? Array
      is == @should
    end

    def validate_value?(_value)
      true
    end
  end

  ensurable do
    desc 'Register or delete runner.'

    newvalue(:present) do
      provider.create
    end
    newvalue(:absent) do
      provider.destroy
    end

    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc 'Runner desription'
  end

  newparam(:description) do
    desc 'The description of a runner'

    defaultto { @resource[:name] }
  end

  newparam(:registration_token) do
    desc 'Runner registration token'

    newvalues(%r{^[_A-Za-z0-9-]+$})

    validate do |value|
      raise ArgumentError, _('Registration token must be provided as a string.') unless value.is_a?(String)
      raise ArgumentError, _('Registration token could not be empty') if value.empty?
    end
  end

  newparam(:tag_list) do
    desc 'The list of tags for a runner; put array of tags, that should be finally assigned to a runner'

    validate do |value|
      if value.is_a? Array
        value.each do |tag|
          raise ArgumentError, _('Each tag must be an alphanumeric string') unless tag.to_s.match?(%r{^[A-Za-z0-9-]+$})
        end
      else
        raise ArgumentError, _('Each tag must be an alphanumeric string') unless value.to_s.match?(%r{^[A-Za-z0-9-]+$})
      end
    end

    munge do |value|
      [value].flatten.compact
    end
  end

  newparam(:run_untagged, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Flag indicating the runner can execute untagged jobs'

    defaultto true
  end

  newparam(:locked, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Flag indicating the runner is locked'

    defaultto false
  end

  newparam(:access_level) do
    desc 'The access_level of the runner'

    newvalues(:not_protected, :ref_protected)
    defaultto :not_protected
  end

  newparam(:config) do
    desc 'Runner configuration file full path'

    defaultto '/srv/gitlab-runner/config/config.toml'

    validate do |value|
      raise ArgumentError, _('Path to GitLab Runner configuration file must be absolute.') unless Puppet::Util.absolute_path?(value)
    end
  end

  newproperty(:gitlab_url) do
    desc 'GitLab URL'

    validate do |value|
      parsed = URI.parse(value)

      unless VALID_GITLAB_SCHEMES.include?(parsed.scheme)
        raise _('Must be a valid URL')
      end
    end

    munge do |value|
      # remove trailing slashes
      value.gsub(%r{/*$}, '')
    end
  end

  # Authentication token
  newproperty(:authentication_token) do
    desc 'Token used to authenticate the runner with the GitLab instance'

    newvalues(%r{^[_A-Za-z0-9-]+$})

    validate do |value|
      raise ArgumentError, _('Authentication token must be provided as a string.') unless value.is_a?(String)
      raise ArgumentError, _('Authentication token could not be empty') if value.empty?
    end
  end

  newproperty(:executor) do
    desc 'Select how a project should be built.'

    newvalues('shell', 'docker', 'docker-windows', 'docker-ssh', 'ssh', 'parallels', 'virtualbox', 'docker+machine', 'docker-ssh+machine', 'kubernetes')

    defaultto 'docker'

    munge do |value|
      value.to_s
    end
  end

  newproperty(:environment, array_matching: :all, parent: ArrayProperty) do
    desc 'Append or overwrite environment variables for runner'

    def validate_value?(value)
      return false, _("Environment variable #{value} must start with valid variable name") unless value.to_s.match?(%r{^[A-Za-z][_A-Za-z0-9]*=})
      true
    end
  end

  newproperty(:docker_volume, array_matching: :all, parent: ArrayProperty) do
    desc 'Additional volumes that should be mounted'

    def validate_value?(value)
      host, cont, _perm = value.split(':', 3)
      if cont
        return false, _("Mount path inside container must be a full path (not #{cont})") unless Puppet::Util.absolute_path?(cont)
        return true if Puppet::Util.absolute_path?(host)
        return true if host.to_s.match?(%r{^[a-zA-Z0-9][a-zA-Z0-9_.-]*$})
        [false, _("#{host} includes invalid characters for a local volume name or it is not a full path")]
      else
        return false, _("Mount path inside container must be a full path (not #{value})") unless Puppet::Util.absolute_path?(value)
        true
      end
    end
  end

  newproperty(:extra_hosts, array_matching: :all, parent: ArrayProperty) do
    desc 'Hosts that should be defined in container environment.'

    def validate_value?(value)
      dom, addr = value.split(':', 2)

      return false, _("Extra host must contain a valid hostname (not #{dom})") unless provider.validate_domain(dom)
      return false, _("Extra host must contain a valid IP address (not #{addr})") unless provider.validate_ip(addr)

      true
    end
  end

  newproperty(:docker_image) do
    desc 'The image to run jobs with.'

    validate do |value|
      raise ArgumentError, _('Docker image name must be provided as a string.') unless value.is_a?(String)
      raise ArgumentError, _('Docker image name could not be empty') if value.empty?
    end
  end

  autorequire(:file) do
    self[:config]
  end

  validate do
    config = self[:config]
    gitlab_url = self[:gitlab_url]
    registration_token = self[:registration_token]
    authentication_token = self[:authentication_token]

    raise Puppet::Error, 'Runner configuration path must be set' unless config
    raise Puppet::Error, 'GitLab URL must be provided' unless gitlab_url
    raise Puppet::Error, 'Either runner registration token or authentication token must be provided' unless registration_token || authentication_token
  end
end
