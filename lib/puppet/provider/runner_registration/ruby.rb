require 'json'
require 'ipaddr'
require 'uri'
require 'net/http'

Puppet::Type.type(:runner_registration).provide(:ruby) do
  @doc = 'Registry auth token provider'

  DEFAULT_CONFIG = {
    'concurrent' => 1,
    'check_interval' => 0,
    'session_server' => {
      'session_timeout' => 1800,
    },
    'runners' => [
      {
        'executor' => 'docker',
        'custom_build_dir' => {},
        'cache' => {
          's3' => {},
          'gcs' => {},
          'azure' => {},
        },
        'docker' => {
          'tls_verify' => false,
          'image' => 'centos:7',
          'privileged' => false,
          'disable_entrypoint_overwrite' => false,
          'oom_kill_disable' => false,
          'disable_cache' => false,
          'volumes' => ['/cache'],
          'shm_size' => 0,
        },
      },
    ],
  }.freeze

  confine true: begin
                  require 'toml'
                rescue LoadError
                  false
                else
                  true
                end

  def initialize(value = {})
    super(value)
    @property_flush = {}
    @auth_info = {}
  end

  def self.validate_ip(ip)
    return nil unless ip
    IPAddr.new(ip)
  rescue ArgumentError
    nil
  end

  def self.validate_domain(dom)
    return nil unless dom
    %r{^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$} =~ dom.downcase
  end

  # configuration file content
  def self.config_content(file_name)
    return '' unless File.exist?(file_name)
    File.read(file_name)
  end

  def self.config_data(file_name)
    content = config_content(file_name)
    return {} if content.empty?

    begin
      TOML::Parser.new(content).parsed
    rescue Parslet::ParseFailed
      {}
    end
  end

  # send request 'req' to server described by URI 'uri'
  def self.req_submit(uri, req, limit = 5)
    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == 'https',
      read_timeout: 5,
      open_timeout: 5,
    ) do |http|
      http.request(req) do |res|
        Puppet.debug("res: {res.code: #{res.code}, res.to_hash: #{res.to_hash}, res.body: #{res.body}}")
        return res.code, res.to_hash, res.body if res.is_a?(Net::HTTPSuccess)

        if res.is_a?(Net::HTTPRedirection)
          # stop redirection loop
          return nil if limit.zero?

          # follow redirection
          url = res['location']

          Puppet.debug("location: {url: #{url}, header: #{header}}")

          return req_submit(URI(url), req, limit - 1)
        end

        return res.code, res.to_hash, nil
      end
    end
  rescue SocketError, Net::OpenTimeout
    Puppet.warning "URL #{uri} fetch error"
    nil
  end

  # use HTTP GET request to the server
  def self.url_get(url, header = {})
    uri = URI(url)
    req = Net::HTTP::Get.new(uri, header)

    Puppet.debug("url_get: {url: #{url}, header: #{header}}")

    req_submit(uri, req)
  end

  # use HTTP POST request to the server
  def self.url_post(url, data, header = { 'Content-Type' => 'application/x-www-form-urlencoded' })
    uri = URI(url)
    req = Net::HTTP::Post.new(uri, header)
    req.body = data

    Puppet.debug("url_post: {url: #{url}, req.body: #{data}}")

    req_submit(uri, req)
  end

  # use HTTP POST request to the server
  def self.url_delete(url, data, header = { 'Content-Type' => 'application/x-www-form-urlencoded' })
    uri = URI(url)
    req = Net::HTTP::Delete.new(uri, header)
    req.body = data

    Puppet.debug("url_delete: {url: #{url}, req.body: #{data}}")

    req_submit(uri, req)
  end

  # retreive authentication information based on token
  def self.auth_info(url, token)
    auth_data  = URI.encode_www_form(token: token)
    verify_url = "#{url}/api/v4/runners/verify"

    Puppet.debug("auth_info: {url: #{url}, token: #{token}}")

    url_post(verify_url, auth_data)
  end

  # authentication status check
  def self.auth_insync?(url, token)
    code, _header, _body = auth_info(url, token)

    code.to_i == 200
  end

  def self.register(url, registration)
    return {} unless registration.is_a?(Hash) && registration[:token]

    reg_data = URI.encode_www_form(registration)
    reg_url = "#{url}/api/v4/runners"

    Puppet.debug("register: {url: #{url}, registration: #{registration}}")

    # https://docs.gitlab.com/ee/api/runners.html#register-a-new-runner
    code, _header, body = url_post(reg_url, reg_data)
    auth_data           = JSON.parse(body) if body

    Puppet.debug("register: {auth_data: #{auth_data}}")

    return auth_data if code.to_i == 201 && auth_data['id'] && auth_data['token']
    {}
  end

  def self.delete(url, token)
    auth_data = URI.encode_www_form(token: token)
    reg_url = "#{url}/api/v4/runners"

    code, _header, _body = url_delete(reg_url, auth_data)

    code.to_i == 204
  end

  def config_path
    @resource[:config]
  end

  def config_content
    @content ||= self.class.config_content(config_path)
  end

  def config_data
    return @data if @data

    data = self.class.config_data(config_path)
    @data = if data.empty?
              {}
            else
              data
            end
  end

  def generate_config
    @content = TOML::Generator.new(config_data).body
  end

  def store_content
    File.open(config_path, 'w') { |f| f.write(config_content) }
  end

  def runner_data
    config_data['runners'] ||= [{}]
    config_data['runners'].first
  end

  def docker_data
    runner_data['docker'] ||= {}
    runner_data['docker']
  end

  # authentication check
  def auth_insync?
    url   = @resource.value(:gitlab_url)
    token = @resource.value(:authentication_token)

    code, _header, body = self.class.auth_info(url, token)

    # authentication could not be verified
    return false unless code.to_i == 200

    # store authentication token information
    # into @auth_info dict (token, id, token_expires_at)
    @auth_info = if body
                   JSON.parse(body)
                 else
                   {}
                 end
    true
  end

  def exists?
    config = @resource[:config]

    # no config file - no registration
    return false unless File.exist?(config)

    # no auth token or no URL - no registration
    return false unless authentication_token && gitlab_url

    # no auth - no registration
    return false unless self.class.auth_insync?(gitlab_url, authentication_token)

    true
  end

  # authentication token check
  def delete_runner
    url   = @resource.value(:gitlab_url)
    token = @resource.value(:authentication_token)

    self.class.delete(url, token)
  end

  def destroy
    # remove registration
    delete_runner if auth_insync?

    runner_data.delete('token')
    runner_data.delete('name')

    generate_config
    store_content
  end

  def register_runner
    token = @resource.value(:registration_token)
    return {} unless token

    url = @resource.value(:gitlab_url)

    desc         = @resource.value(:description)
    tag_list     = @resource.value(:tag_list)
    access_level = @resource.value(:access_level)
    run_untagged = @resource[:run_untagged]
    locked       = @resource[:locked]

    registration                = { token: token }
    registration[:description]  = desc if desc
    registration[:tag_list]     = tag_list.join(',') if tag_list && tag_list.is_a?(Array)
    registration[:run_untagged] = run_untagged
    registration[:locked]       = locked
    registration[:access_level] = access_level.to_s if access_level

    # https://docs.gitlab.com/ee/api/runners.html#register-a-new-runner
    self.class.register(url, registration)
  end

  # curl --request POST "https://build.domain.com/api/v4/runners" \
  # --form "token=biQgCE4CYrKucV6zsKxW" --form "description=build-runner" \
  # --form "tag_list=rpm,rpmb,bsys,build" --form "run_untagged=true" \
  # --form "locked=false" --form "access_level=not_protected"
  def create
    name         = @resource[:name]
    # if no config file - register runner
    reg_token    = @resource.value(:registration_token)
    auth_token   = @resource.value(:authentication_token)
    url          = @resource.value(:gitlab_url)
    executor     = @resource.value(:executor)
    docker_image = @resource.value(:docker_image)
    environment  = @resource.value(:environment)
    volumes      = @resource.value(:docker_volume)
    extra_hosts  = @resource.value(:extra_hosts)

    # propagate default configuration file content if not exists
    # runner_data and runner_data methods make preset
    if config_data.empty? || config_data == { 'runners' => [{}] } || config_data == { 'runners' => [{ 'docker' => {} }] }
      @data = DEFAULT_CONFIG
    end

    runner_data['url']  = url
    runner_data['name'] = name
    runner_data['executor'] = executor if executor
    docker_data['image'] = docker_image if docker_image
    runner_data['environment'] = environment if environment
    docker_data['volumes'] = volumes if volumes
    docker_data['extra_hosts'] = extra_hosts if extra_hosts

    # already registered - just update configuration file
    if auth_token && auth_insync?
      runner_data['token'] = auth_token
      runner_data['id'] = @auth_info['id'] unless @auth_info.empty?
    # registration
    elsif reg_token
      auth_data = register_runner
      runner_data['token'] = auth_data['token'] unless auth_data.empty?
      runner_data['id'] = auth_data['id'] unless auth_data.empty?
    end

    generate_config
    store_content
  end

  def authentication_token
    runner_data['token']
  end

  def authentication_token=(token)
    @property_flush[:authentication_token] = token
  end

  def gitlab_url
    runner_data['url']
  end

  def gitlab_url=(url)
    @property_flush[:gitlab_url] = url
  end

  def executor
    runner_data['executor']
  end

  def executor=(exec)
    @property_flush[:executor] = exec
  end

  def docker_image
    docker_data['image']
  end

  def docker_image=(image)
    @property_flush[:docker_image] = image
  end

  def environment
    runner_data['environment']
  end

  def environment=(env)
    @property_flush[:environment] = env
  end

  def docker_volume
    docker_data['volumes']
  end

  def docker_volume=(volumes)
    @property_flush[:docker_volume] = volumes
  end

  def extra_hosts
    docker_data['extra_hosts']
  end

  def extra_hosts=(hosts)
    @property_flush[:extra_hosts] = hosts
  end

  def flush
    return if @property_flush.empty?

    reg_token = @resource.value(:registration_token)
    url = @property_flush[:gitlab_url] || @resource.value(:gitlab_url) || gitlab_url
    auth_token = @property_flush[:authentication_token] || @resource.value(:authentication_token) || authentication_token

    # in case if GitLab URL has been changed
    if @property_flush[:gitlab_url]
      if auth_token && self.class.auth_insync?(url, auth_token)
        runner_data['url']   = url
        runner_data['token'] = auth_token
      elsif reg_token
        auth_data = register_runner
        unless auth_data.empty?
          runner_data['url']   = url
          runner_data['token'] = auth_data['token']
        end
      end
    elsif @property_flush[:authentication_token]
      if self.class.auth_insync?(url, auth_token)
        runner_data['url']   = url
        runner_data['token'] = auth_token
      end
    end

    runner_data['executor'] = @property_flush[:executor] if @property_flush[:executor]
    runner_data['environment'] = @property_flush[:environment] if @property_flush[:environment]
    docker_data['image'] = @property_flush[:docker_image] if @property_flush[:docker_image]
    docker_data['volumes'] = @property_flush[:docker_volume] if @property_flush[:docker_volume]
    docker_data['extra_hosts'] = @property_flush[:extra_hosts] if @property_flush[:extra_hosts]

    generate_config
    store_content

    @property_flush.clear
  end

  def validate_ip(ip)
    self.class.validate_ip(ip)
  end

  def validate_domain(dom)
    self.class.validate_domain(dom)
  end
end
