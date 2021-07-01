require 'time'
require 'openssl'

Puppet::Type.type(:runner_registration).provide(:ruby) do
  @doc = 'Registry auth token provider'

  confine true: begin
                  require 'toml'
                rescue LoadError
                  false
                else
                  true
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

  # {
  #   "concurrent"=>1,
  #   "check_interval"=>0,
  #   "session_server"=>{
  #     "session_timeout"=>1800
  #   },
  #   "runners"=>[
  #     {
  #       "name"=>"build-runner",
  #       "url"=>"https://build.domain.com/",
  #       "token"=>"7ij2E77cgc65dJHFf6zo",
  #       "executor"=>"docker",
  #       "custom_build_dir"=>{},
  #       "cache" => {
  #         "s3"=>{},
  #         "gcs"=>{},
  #         "azure"=>{}
  #       },
  #       "docker"=>{
  #         "tls_verify"=>false,
  #         "image"=>"centos:7",
  #         "privileged"=>false,
  #         "disable_entrypoint_overwrite"=>false,
  #         "oom_kill_disable"=>false,
  #         "disable_cache"=>false,
  #         "volumes"=>["/cache"],
  #         "shm_size"=>0
  #       }
  #     }
  #   ]
  # }

  def runner_data
    config_data['runners'].first
  end

  def authentication_token
    runner_data['token']
  end

  def gitlab_url
    runner_data['url']
  end

  def auth_insync?

  end

  def generate_config
    # content = { 'token' => authorized_token.encoded }
    # content['access'] = resource_access

    # @content = content.to_json
  end

  def store_content
    File.open(config_path, 'w') { |f| f.write(config_content) }
  end

  def exists?

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

  end

  def create

  end

  def flush
    return if @property_flush.empty?

    generate_content
    store_content

    @property_flush.clear
  end
end
