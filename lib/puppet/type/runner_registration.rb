require 'uri'

Puppet::Type.newtype(:runner_registration) do
  @doc = 'GitLab runner registration'

  VALID_SCHEMES = ['http', 'https'].freeze

  # docker run --rm -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner:v14.0.1 register \
  # --non-interactive \
  # --executor "docker" \
  # --docker-image centos:7 \
  # --url "https://gitlab.domain.com/" \
  # --registration-token "biQgCE4CYrKucV6zsKxW" \
  # --description "gitlab-runner" \
  # --tag-list "rpm,rpmb,bsys,build" \
  # --run-untagged="true" \
  # --locked="false" \
  # --access-level="not_protected"

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
          raise ArgumentError, _('Each tag must be an alphanumeric string') unless tag.to_s =~ %r{^[A-Za-z0-9-]+$}
        end
      else
        raise ArgumentError, _('Each tag must be an alphanumeric string') unless value.to_s =~ %r{^[A-Za-z0-9-]+$}
      end
    end

    munge do |value|
      [value].flatten.compact
    end
  end

  newparam(:run_untagged, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Flag indicating the runner can execute untagged jobs'

    defaultto :true
  end

  newparam(:locked, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc 'Flag indicating the runner is locked'

    defaultto :false
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
      raise ArgumentError, _('Path to GitLab Runner configuration file must be absolute.') unless Puppet::Util.absolute_path?(path)
    end
  end

  newproperty(:gitlab_url) do
    desc 'GitLab URL'

    validate do |value|
      parsed = URI.parse(value)

      unless VALID_SCHEMES.include?(parsed.scheme)
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
      raise ArgumentError, _('Registration token must be provided as a string.') unless value.is_a?(String)
      raise ArgumentError, _('Registration token could not be empty') if value.empty?
    end

    def insync?(is)
      insync = super(is)
      provider.auth_insync?
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

    raise Puppet::Error, 'Runner cconfiguration path must be set' unless config
    raise Puppet::Error, 'GitLab URL must be provided' unless gitlab_url
    raise Puppet::Error, 'Runner registration token must be provided' unless registration_token
  end
end