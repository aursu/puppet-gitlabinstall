#!/opt/puppetlabs/puppet/bin/ruby

require 'optparse'
require 'ostruct'
require 'uri'
require 'net/http'
require 'json'

#
class OptparseExample
  #
  # Return a structure describing the options.
  #
  def initialize
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    @options = OpenStruct.new
    @options.url = nil
    @options.token = nil
    @options.delete = false

    @opt_parser = OptionParser.new do |opts|
      opts.banner = 'Usage: gitlab.rb [options]'

      opts.separator ''
      opts.separator 'Specific options:'

      opts.on('-u', '--url URL', 'GitLab URL') do |url|
        @options.url = url
      end

      opts.on('-t', '--token TOKEN', 'Personal access token. See https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html') do |token|
        @options.token = token
      end

      opts.on('-g', '--group GROUP', 'GitLab group') do |group|
        @options.group = group
      end

      opts.on('-p', '--project [PROJECT]', 'GitLab project') do |project|
        @options.project = project
      end

      opts.on('-d', '--deploy-key [KEY]', 'Deploy key to enable for project') do |key|
        @options.deploy_key = key
      end

      # Boolean switch.
      opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
        @options.verbose = v
      end

      opts.on('--[no-]delete', 'Delete project') do |d|
        @options.delete = d
      end

      opts.separator ''
      opts.separator 'Common options:'

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end
  end

  def parse(args)
    @opt_parser.parse!(args)

    process_env
    validate

    return @options, args # rubocop:disable Style/RedundantReturn
  end

  def process_env
    @options.url = ENV['GITLAB_URL'] if @options.url.nil? && ENV.include?('GITLAB_URL')
    @options.token = ENV['PRIVATE_TOKEN'] if @options.token.nil? && ENV.include?('PRIVATE_TOKEN')
  end

  def validate
    if @options.url.nil?
      puts @opt_parser.help
      raise OptionParser::ParseError, 'GitLab URL is not provided'
    end

    if @options.token.nil?
      puts @opt_parser.help
      raise OptionParser::ParseError, 'Personal access token is not provided'
    end

    if @options.group.nil?
      puts @opt_parser.help
      raise OptionParser::ParseError, 'GitLab group is mandatory parameter'
    end

    # we do not need Deploy Key if projects going to be deleted
    return if @options.delete
    return unless @options.deploy_key.nil?

    puts @opt_parser.help
    raise OptionParser::ParseError, 'Deploy token name or id is mandatory parameter'
  end
end # class OptparseExample

# OpenStack client
class GitLabAPIClient
  def initialize(gitlab_url, access_token)
    @url = gitlab_url
    @token = access_token
  end

  # send request 'req' to server described by URI 'uri'
  def req_submit(uri, req, limit = 5)
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
    nil
  end

  # use HTTP GET request to the server
  def url_get(url, header = {})
    uri = URI(url)
    req = Net::HTTP::Get.new(uri, header)

    req_submit(uri, req)
  end

  # use HTTP POST request to the server
  def url_post(url, data = nil, header = { 'Content-Type' => 'application/json' })
    uri = URI(url)
    req = Net::HTTP::Post.new(uri, header)
    req.body = data unless data.nil? || data.empty?

    req_submit(uri, req)
  end

  # use HTTP POST request to the server
  def url_delete(url, header = {})
    uri = URI(url)
    req = Net::HTTP::Delete.new(uri, header)

    req_submit(uri, req)
  end

  def api_url(request_uri)
    gitlab_uri = URI(@url)
    api_host   = gitlab_uri.host
    api_scheme = gitlab_uri.scheme

    api = "#{api_scheme}://#{api_host}/api/v4"
    request_uri.sub!(%r{/+}, '')

    "#{api}/#{request_uri}"
  end

  def auth_token
    return @token if @token
    nil
  end

  def api_get(request_uri)
    url = api_url(request_uri)
    return nil unless url

    body_hash = nil

    _code, _header, body = url_get(url, 'PRIVATE-TOKEN' => auth_token)
    body_hash = JSON.parse(body) if body

    body_hash
  end

  def api_get_list(request_uri, key = 'title', filter = [])
    ret = {}
    jout = api_get(request_uri)
    jout.each do |p|
      idx = p[key]
      ret[idx] = p.reject { |k, _v| k == key || filter.include?(k.to_sym) }
    end
    ret
  end

  def api_post(request_uri, data = nil)
    url = api_url(request_uri)
    return nil unless url

    body_hash = nil

    code, _header, body = url_post(url, data, { 'PRIVATE-TOKEN' => auth_token })
    body_hash = JSON.parse(body) if body

    return code, body_hash # rubocop:disable Style/RedundantReturn
  end

  def api_delete(request_uri)
    url = api_url(request_uri)
    return nil unless url

    body_hash = nil

    code, _header, body = url_delete(url, { 'PRIVATE-TOKEN' => auth_token })
    body_hash = JSON.parse(body) if body

    return code, body_hash # rubocop:disable Style/RedundantReturn
  end
end

# GitLab API object
#
class GitLabObject
  # GitLab client
  attr_accessor :client, :object

  def initialize(client = nil)
    @client = client if client && client.is_a?(GitLabAPIClient)

    @object = {}
  end
end

# GitLab Group API object
#
class GitLabGroup < GitLabObject
  def initialize(name, client = nil)
    raise ArgumentError, 'GitLabGroup name must be non-empty string' if name.nil? || name.empty?

    @name = name

    super(client)
  end

  def get
    return @object unless @object.nil? || @object.empty?
    return nil unless @client

    id = URI.encode_www_form_component(@name)
    @object = @client.api_get("/groups/#{id}")

    @object
  end

  # @param fields
  #   return only those fields for each project which specified
  #
  def projects(fields = [])
    object = get
    object_projects = []

    object_projects = object['projects'] if object.include?('projects')

    if fields.empty?
      object_projects
    else
      object_projects.map { |p| p.filter { |k, _v| fields.include?(k) || fields.include?(k.to_sym) } }
    end
  end

  def projects_group_path(url_encode = false)
    projects.map do |p|
      if url_encode
        URI.encode_www_form_component("#{@name}/%s" % [p['path']])
      else
        "#{@name}/%s" % [p['path']]
      end
    end
  end
end

# GitLab Deploy Key API object
#
class GitLabDeployKey < GitLabObject
  def initialize(name, client = nil)
    raise ArgumentError, 'GitLabDeployKey name or id must be non-empty string' if name.nil? || name.empty?

    @name = name

    super(client)
  end

  def get
    return @object unless @object.nil? || @object.empty?
    return nil unless @client

    keys = @client.api_get('/deploy_keys').filter { |k| k['id'] == @name || k['title'] == @name }
    return nil if keys.nil? || keys.empty?

    # first key is our object
    @object = keys[0]

    @object
  end
end

# GitLab Project API object
#
class GitLabProject < GitLabObject
  def initialize(path, client = nil)
    raise ArgumentError, 'GitLabProject path must be non-empty string' if path.nil? || path.empty?

    @path = path
    super(client)

    @deploy_keys = []
  end

  def get(force_check = false)
    unless force_check
      return @object unless @object.nil? || @object.empty?
    end
    return nil unless @client

    id = URI.encode_www_form_component(@path)
    @object = @client.api_get("/projects/#{id}")

    @object
  end

  def delete
    project = get(true)
    return true if project.nil? || project.empty?

    return nil unless @client

    id = URI.encode_www_form_component(@path)
    code, _body = @client.api_delete("/projects/#{id}")

    code.to_s == '202'
  end

  # list of deploy keys for project
  #
  def deploy_keys
    return @deploy_keys unless @deploy_keys.nil? || @deploy_keys.empty?

    project = get
    return nil if project.nil? || project.empty?

    id = project['id']
    @deploy_keys = @client.api_get("/projects/#{id}/deploy_keys")

    @deploy_keys
  end

  # check if deploy key enabled for project
  #
  # @param key
  #   Either GitLabDeployKey key object or deploy key name/id
  #
  def deploy_key_check(key)
    id = key
    id = key.get['id'] if key.is_a?(GitLabDeployKey)

    return false if id.nil? || id.to_s.empty?

    keys = deploy_keys.filter { |k| k['id'] == id || k['title'] == id }

    # false if keys are empty or anything wrong
    return false if keys.nil? || keys.empty?

    true
  end

  # enable deploy key for project
  #
  # @param key
  #   Either GitLabDeployKey key object or deploy key name/id
  #
  def deploy_key_enable(key)
    return true if deploy_key_check(key)

    key_id = if key.is_a?(GitLabDeployKey)
               key.get['id']
             else
               GitLabDeployKey.new(key, @client).get['id']
             end

    return nil if key_id.nil? || key_id.to_s.empty?

    project = get
    return nil if project.nil? || project.empty?

    id = project['id']
    code, _body = @client.api_post("/projects/#{id}/deploy_keys/#{key_id}/enable")

    code.to_s == '201'
  end
end

# parse command line arguments and environment variables
options, _argv = OptparseExample.new.parse(ARGV)

# GitLab REST API client
client = GitLabAPIClient.new(options.url, options.token)

# GitLab group to process
group = GitLabGroup.new(options.group, client)

# Print all projects' paths inside group
puts JSON.pretty_generate(group.projects_group_path)

if options.delete
  group.projects_group_path.each do |p|
    project = GitLabProject.new(p, client)
    puts p

    puts project.delete
  end
else
  # Deploy Key to enable for all projects inside provided group
  deploy_key = GitLabDeployKey.new(options.deploy_key, client)

  group.projects_group_path.each do |p|
    project = GitLabProject.new(p, client)
    puts p

    if project.deploy_key_check(deploy_key)
      puts JSON.pretty_generate(project.deploy_keys)
    else
      puts project.deploy_key_enable(deploy_key)
    end
  end
end
