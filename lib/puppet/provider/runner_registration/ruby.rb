require 'json'

Puppet::Type.type(:runner_registration).provide(:ruby) do
  @doc = 'Registry auth token provider'

  DEFAULT_CONFIG = {
    'concurrent' => 1,
    'check_interval' => 0,
    'session_server' => {
      'session_timeout' => 1800
    },
    'runners' => [
      {
        # 'name' => '',
        # 'url' => '',
        # 'token' => '',
        'executor' => 'docker',
        'custom_build_dir' => {},
        'cache' => {
          's3' => {},
          'gcs' => {},
          'azure' => {}
        },
        'docker' => {
          'tls_verify' => false,
          'image' => 'centos:7',
          'privileged' => false,
          'disable_entrypoint_overwrite' => false,
          'oom_kill_disable' => false,
          'disable_cache' => false,
          'volumes' => ['/cache'],
          'shm_size' => 0
        }
      }
    ]
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
      return TOML::Parser.new(content).parsed
    rescue Parslet::ParseFailed
      return {}
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
        return res.code, res.to_hash, res.body if res.is_a?(Net::HTTPSuccess)

        if res.is_a?(Net::HTTPRedirection)
          # stop redirection loop
          return nil if limit.zero?

          # follow redirection
          url = res['location']
          return req_submit(URI(url), req, limit - 1)
        end

        return res.code, res.to_hash, nil
      end
    end
  rescue SocketError, Net::OpenTimeout
    Puppet.warning "URL #{uri} fetch error"
    return nil
  end

  # use HTTP GET request to the server
  def self.url_get(url, header = {})
    uri = URI(url)
    req = Net::HTTP::Get.new(uri, header)

    req_submit(uri, req)
  end

  # use HTTP POST request to the server
  def self.url_post(url, data, header = { 'Content-Type' => 'application/x-www-form-urlencoded' })
    uri = URI(url)
    req = Net::HTTP::Post.new(uri, header)
    req.body = data

    req_submit(uri, req)
  end

  # use HTTP POST request to the server
  def self.url_delete(url, data, header = { 'Content-Type' => 'application/x-www-form-urlencoded' })
    uri = URI(url)
    req = Net::HTTP::Delete.new(uri, header)
    req.body = data

    req_submit(uri, req)
  end

  # authentication token check
  def self.auth_insync?(gitlab_url, token)
    auth_data  = URI.encode_www_form(token: token)
    verify_url = "#{gitlab_url}/api/v4/runners/verify"

    code, _header, _body = url_post(verify_url, auth_data)

    code.to_i == 200
  end

  def self.register(gitlab_url, registration)
    return {} unless  registration.is_a? Hash && registration['token']

    reg_data  = URI.encode_www_form(registration)
    reg_url = "#{gitlab_url}/api/v4/runners"

    # https://docs.gitlab.com/ee/api/runners.html#register-a-new-runner
    code, _header, body = url_post(reg_url, reg_data)
    auth_data           = JSON.parse(body) if body

    return {} unless code.to_i == 201
    return auth_data if auth_data['id'] && auth_data['token']
    return {}
  end

  def self.delete(gitlab_url, token)
    auth_data  = URI.encode_www_form(token: token)
    reg_url = "#{gitlab_url}/api/v4/runners"

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

  def runner_data
    config_data['runners'].first
  end

  def authentication_token
    runner_data['token']
  end

  def gitlab_url
    runner_data['url']
  end

  # authentication token check
  def auth_insync?
    url   = @resource.value(:gitlab_url)
    token = @resource.value(:authentication_token)

    return self.class.auth_insync?(url, token)
  end

  def generate_config
    @content = TOML::Generator.new(config_data).body
  end

  def store_content
    File.open(config_path, 'w') { |f| f.write(config_content) }
  end

  def exists?
    config = @resource[:config]

    # no config file - no registration
    return false unless File.exist?(config)

    # no auth token or no URL - no registration
    return false unless authentication_token && gitlab_url

    # no auth - no registration
    return false unless self.class.auth_insync?(gitlab_url, authentication_token)
  end

  # authentication token check
  def delete_runner
    url   = @resource.value(:gitlab_url)
    token = @resource.value(:authentication_token)

    return self.class.delete(url, token)
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
    token        = @resource.value(:registration_token)
    gitlab_url   = @resource.value(:gitlab_url)

    desc         = @resource.value(:description)
    tag_list     = @resource.value(:tag_list).join(',')
    access_level = @resource.value(:access_level)
    run_untagged = @resource.run_untagged?
    locked       = @resource.locked?

    registration                = { token: token }
    registration[:description]  = desc if desc
    registration[:tag_list]     = tag_list.join(',') if tag_list && tag_list.is_a?(Array)
    registration[:run_untagged] = run_untagged
    registration[:locked]       = locked
    registration[:access_level] = access_level if access_level

    # https://docs.gitlab.com/ee/api/runners.html#register-a-new-runner
    self.class.register(gitlab_url, registration)
  end

  # curl --request POST "https://build.domain.com/api/v4/runners" \
  # --form "token=biQgCE4CYrKucV6zsKxW" --form "description=build-runner" \
  # --form "tag_list=rpm,rpmb,bsys,build" --form "run_untagged=true" \
  # --form "locked=false" --form "access_level=not_protected"
  def create
    name         = @resource[:name]
    # if no config file - register runner
    config_path  = @resource[:config]
    auth_token   = @resource.value(:authentication_token)
    gitlab_url   = @resource.value(:gitlab_url)

    # propagate default configuration file content if not exists
    if config_data.empty?
      @data = DEFAULT_CONFIG
    end

    runner_data['url']  = gitlab_url
    runner_data['name'] = name

    # already registered - just update configuration file
    if auth_token && auth_insync?
      runner_data['token'] = auth_token
    # registration
    else
      auth_data = register_runner
      runner_data['token'] = auth_data['token'] unless auth_data.empty?
    end

    generate_config
    store_content
  end

  def flush
    return if @property_flush.empty?

    generate_content
    store_content

    @property_flush.clear
  end
end
