require 'uri'

Puppet::Type.newtype(:runner_registration) do
  @doc = 'GitLab runner registration'

  VALID_SCHEMES = ['http', 'https'].freeze

  # concurrent = 1
  # check_interval = 0
  #
  # [session_server]
  #   session_timeout = 1800
  #
  # [[runners]]
  #   name = "build-runner"
  #   url = "https://build.domain.com/"
  #   token = "7ij2E77cgc65dJHFf6zo"
  #   executor = "docker"
  #   [runners.custom_build_dir]
  #   [runners.cache]
  #     [runners.cache.s3]
  #     [runners.cache.gcs]
  #     [runners.cache.azure]
  #   [runners.docker]
  #     tls_verify = false
  #     image = "centos:7"
  #     privileged = false
  #     disable_entrypoint_overwrite = false
  #     oom_kill_disable = false
  #     disable_cache = false
  #     volumes = ["/cache"]
  #     shm_size = 0

  # docker run --rm -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner:v14.0.1 register \
  # --non-interactive \
  # --executor "docker" \
  # --docker-image centos:7 \
  # --url "https://build.domain.com/" \
  # --registration-token "biQgCE4CYrKucV6zsKxW" \
  # --description "build-runner" \
  # --tag-list "rpm,rpmb,bsys,build" \
  # --run-untagged="true" \
  # --locked="false" \
  # --access-level="not_protected"

  # curl --request POST "https://build.domain.com/api/v4/runners" \
  # --form "token=biQgCE4CYrKucV6zsKxW" --form "description=build-runner" \
  # --form "tag_list=rpm,rpmb,bsys,build" --form "run_untagged=true" \
  # --form "locked=false" --form "access_level=not_protected"

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

  newparam(:registration_token) do
    desc 'Runner registration token'

    newvalues(%r{^[_A-Za-z0-9-]+$})

    validate do |value|
      raise ArgumentError, _('Registration token must be provided as a string.') unless value.is_a?(String)
      raise ArgumentError, _('Registration token could not be empty') if value.empty?
    end
  end

  newparam(:description) do
    desc 'The description of a runner'

    defaultto { @resource[:name] }
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

  # Authentication token
  newproperty(:authentication_token) do
    desc 'Token used to authenticate the runner with the GitLab instance'

    newvalues(%r{^[_A-Za-z0-9-]+$})

    validate do |value|
      raise ArgumentError, _('Registration token must be provided as a string.') unless value.is_a?(String)
      raise ArgumentError, _('Registration token could not be empty') if value.empty?
    end

    def insync?(_is)
      provider.auth_insync?
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

  autobefore(:file) do
    self[:config]
  end

  # This will generate additional File[path] resource to setuo permissions
  # or delete token file
  def generate
    target = self[:config]

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
    registration_token = self[:registration_token]

    raise Puppet::Error, 'Runner registration token must be provided' unless registration_token
  end
end
