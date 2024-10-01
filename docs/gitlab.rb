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
    @options.resource = nil
    @options.deploy_key_data = nil
    @options.deploy_key_push = false
    @options.action = 'list'

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
        @options.resource = 'project'
        @options.project = project
      end

      opts.on('-d', '--deploy-key [KEY]', 'Deploy key to work with') do |key|
        @options.resource = 'deploy_key'
        @options.deploy_key = key
      end

      opts.on('--deploy-key-data KEYDATA', 'Deploy key data to work with') do |key|
        @options.deploy_key_data = key
      end

      opts.on('--[no-]deploy-key-push', 'Enable deploy key push capability') do |p|
        @options.deploy_key_push = p
      end

      # Boolean switch.
      opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
        @options.verbose = v
      end

      opts.on('--delete', 'Delete resource') do
        @options.action = 'delete'
      end

      opts.on('--purge', 'Delete resource(s) within group') do
        @options.action = 'purge'
      end

      opts.on('--create', 'Create resource(s)') do
        @options.action = 'create'
      end

      opts.on('--enable', 'Enable resource (e.g. Deploy key for project)') do
        @options.action = 'enable'
      end

      opts.on('--show', 'Show resource details') do
        @options.action = 'show'
      end

      opts.on('--list', 'Display resource(s)') do
        @options.action = 'list'
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

    return unless @options.deploy_key.is_a?(String)
    raise OptionParser::ParseError, 'Personal access token is not provided' unless @options.deploy_key
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

  # use HTTP POST request to the server
  def url_put(url, data = nil, header = { 'Content-Type' => 'application/json' })
    uri = URI(url)
    req = Net::HTTP::Put.new(uri, header)
    req.body = data unless data.nil? || data.empty?

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

  def api_post(request_uri, data = nil, headers = { 'Content-Type' => 'application/json' })
    url = api_url(request_uri)
    return nil unless url

    body_hash = nil

    req_headers = { 'PRIVATE-TOKEN' => auth_token }
    req_headers.merge!(headers) if headers.is_a?(Hash)

    code, _header, body = url_post(url, data, req_headers)
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

  def api_put(request_uri, data = nil, headers = { 'Content-Type' => 'application/json' })
    url = api_url(request_uri)
    return nil unless url

    body_hash = nil

    req_headers = { 'PRIVATE-TOKEN' => auth_token }
    req_headers.merge!(headers) if headers.is_a?(Hash)

    code, _header, body = url_put(url, data, req_headers)
    body_hash = JSON.parse(body) if body

    return code, body_hash # rubocop:disable Style/RedundantReturn
  end
end

# GitLab API object
#
class GitLabObject
  # GitLab client
  attr_accessor :client, :object

  @@client = nil

  def self.set_client(client = nil)
    @@client = client if client && client.is_a?(GitLabAPIClient)
  end

  def initialize(client = nil)
    self.class.set_client(client)
    @client = self.class.get_client

    @object = {}
  end

  def self.get_client
    @@client
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
      object_projects.map { |p| p.select { |k, _v| fields.include?(k) || fields.include?(k.to_sym) } }
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

  def self.groups
    get_client.api_get('/groups')
  end
end

# GitLab Deploy Key API object
#
class GitLabDeployKey < GitLabObject
  attr_accessor :name

  def initialize(name, client = nil)
    raise ArgumentError, 'GitLabDeployKey name or id must be non-empty string' if name.nil? || name.to_s.empty?

    @name = name

    super(client)
  end

  # get Deploy Key by id or title
  def get
    return @object unless @object.nil? || @object.empty?
    return nil unless @client

    keys = deploy_keys.select { |k| k['id'] == @name || k['title'] == @name }
    return nil if keys.nil? || keys.empty?

    # first key is our object
    @object = keys[0]

    @object
  end

  # get deploy key by key data
  #
  def self.get_key(key_data)
    return nil unless get_client

    # key data must be a string
    return nil if key_data.nil? || key_data.to_s.empty?

    _type, key, _name = key_data.split(%r{\s+}, 3)

    # something wrong in provided key data format
    return false if key.nil? || key.to_s.empty?

    keys = deploy_keys.select { |k| k['key'].include?(key) }
    return nil if keys.nil? || keys.empty?

    # return first key
    keys[0]
  end

  def self.deploy_keys
    get_client.api_get('/deploy_keys')
  end

  def deploy_keys
    self.class.deploy_keys
  end
end

# GitLab Project API object
#
class GitLabProject < GitLabObject
  attr_accessor :name, :group

  def initialize(path, client = nil)
    raise ArgumentError, 'GitLabProject path must be non-empty string' if path.nil? || path.empty?

    @path = path
    super(client)

    @deploy_keys = []

    @group, sep, @name = @path.rpartition('/')
    @group = nil unless sep == '/'
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

  def create(group = nil)
    return true if get(true)

    group = @group if @group

    group_id = if group.is_a?(GitLabGroup)
                 group.get['id']
               elsif group
                 GitLabGroup.new(group, @client).get['id']
               else
                 nil
               end

    project_data = {
      name: @name,
      initialize_with_readme: true,
      namespace_id: group_id,
    }

    code, body_hash = @client.api_post('/projects', project_data.to_json)

    return body_hash if code.to_s == '201'
    false
  end

  # list of deploy keys for project
  #
  def deploy_keys
    return @deploy_keys unless @deploy_keys.nil? || @deploy_keys.empty?

    project = get
    return [] if project.nil? || project.empty?

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

    keys = deploy_keys.select { |k| k['id'] == id || k['title'] == id }

    # false if keys are empty or anything wrong
    return false if keys.nil? || keys.empty?

    # return key
    keys[0]
  end

  # enable deploy key for project
  #
  # @param key
  #   Either GitLabDeployKey key object or deploy key name/id
  #
  def deploy_key_enable(key)
    key_check = deploy_key_check(key)
    return key_check if key_check

    key_id = if key.is_a?(GitLabDeployKey)
               key.get['id']
             else
               GitLabDeployKey.new(key, @client).get['id']
             end

    return false if key_id.nil? || key_id.to_s.empty?

    project = get
    return false if project.nil? || project.empty?

    id = project['id']
    code, body_hash = @client.api_post("/projects/#{id}/deploy_keys/#{key_id}/enable")

    return body_hash if code.to_s == '201'
    false
  end

  # check if deploy key with specified key data enabled for project
  #
  # @param key_data
  #   SSH public key data in format '(ssh-rsa|ssh-ed25519|...) <key_data>[ <name>]'
  #
  def deploy_key_data_check(key_data)
    return false if key_data.nil? || key_data.to_s.empty?

    _type, key, _name = key_data.split(%r{\s+}, 3)

    return false if key.nil? || key.to_s.empty?

    keys = deploy_keys.select { |k| k['key'].include?(key) }

    # false if keys are empty or anything wrong
    return false if keys.nil? || keys.empty?

    true
  end

  # enable deploy key for project
  #
  # @param key_title
  #   SSH public key title in GitLab
  #
  # @param key_data
  #   SSH public key data in format '(ssh-rsa|ssh-ed25519|...) <key_data>[ <name>]'
  #
  def deploy_key_data_enable(key_title, key_data, can_push = false)
    return true if deploy_key_data_check(key_data)

    key_object = GitLabDeployKey.get_key(key_data)
    if key_object
      deploy_key_enable(key_object['id'])
      return deploy_key_push(key_object['id'], can_push)
    end

    project = get
    return nil if project.nil? || project.empty?

    key_post_data = {
      title: key_title,
      key: key_data,
      can_push: can_push,
    }

    id = project['id']
    code, body_hash = @client.api_post("/projects/#{id}/deploy_keys", key_post_data.to_json)

    return body_hash if code.to_s == '201'
    false
  end

  def deploy_key_push(key, can_push = false)
    key_check = deploy_key_check(key)
    return false unless key_check

    key_id, key_can_push = ['id', 'can_push'].map { |p| key_check[p] }

    return key_check if can_push == key_can_push

    project = get
    return false if project.nil? || project.empty?

    key_put_data = {
      can_push: can_push,
    }

    id = project['id']
    code, body_hash = @client.api_put("/projects/#{id}/deploy_keys/#{key_id}", key_put_data.to_json)

    return body_hash if code.to_s == '200'
    false
  end
end

# parse command line arguments and environment variables
options, argv = OptparseExample.new.parse(ARGV)

# GitLab REST API client
client = GitLabAPIClient.new(options.url, options.token)

# create GitLabGroup object if provided
options_group = nil
if options.group.is_a?(String) && options.group
  options_group = GitLabGroup.new(options.group, client)
end

# JSON file content:
# {
#   "group/project-1":
#     [
#       {
#         "id": 1,
#         "title": "key1",
#         "key": "ssh-rsa <public key base64-encode data> [optional key1 name]",
#       }
#     ],
#   "group/project-2":
#     [
#       {
#         "id": 2,
#         "title": "key2",
#         "key": "ssh-rsa <public key base64-encode data> [optional key2 name]",
#       },
#       {
#         "id": 1,
#         "title": "key1",
#         "key": "ssh-rsa <public key base64-encode data> [optional key1 name]",
#       }
#     ]
# }

# check for files to parse
if argv && argv[0]
  argv.each do |config|
    puts "Read file: #{config}"
    begin
      # token raw content
      config_data = File.read(config)

      # token JSON data
      group_content = JSON.parse(config_data)
      group_content.each do |project_path, project_keys|
        project = GitLabProject.new(project_path, client)

        if project.group
          puts JSON.pretty_generate(project.create)
        elsif options_group
          puts JSON.pretty_generate(project.create(options_group))
        else
          puts "Group is not specified in project path #{project_path}. Use --group option to define it"
        end

        project_keys.each do |key_object|
          if key_object['key']
            puts JSON.pretty_generate(project.deploy_key_data_enable(key_object['title'], key_object['key']))
          end
        end
      end
    rescue SystemCallError
      puts "System error (can not open file #{config})"
      next
    rescue JSON::ParserError
      puts "JSON error (can not parse file #{config})"
      next
    end
  end
  exit(0)
end

# create GitLabProject object if provided
options_project = nil
if options.project.is_a?(String) && options.project
  options_project = GitLabProject.new(options.project, client)
end

options_deploy_key = nil
if options.deploy_key.is_a?(String) && options.deploy_key
  options_deploy_key = GitLabDeployKey.new(options.deploy_key, client)
end

case options.action
when 'delete'
  # delete project
  if options.resource == 'project'
    # if project name has been prvided - delete single project
    if options_project
      # print delete operation status
      puts options_project.delete
    else
      puts 'Project path/id was not provided'
      puts "Use option --purge to delete all projects inside group #{options.group}" if options_group
    end
  end
when 'purge'
  # purge all projects
  if options.resource == 'project'
    # inside group
    if options_group
      options_group.projects_group_path.each do |p|
        group_project = GitLabProject.new(p, client)

        puts group_project.delete
      end
    else
      puts 'Group was not provided to purge'
    end
  end
when 'create'
  # goinng to create project
  if options.resource == 'project' && options_project
    # as part of the group
    if options_group
      puts JSON.pretty_generate(options_project.create(options_group))
    elsif options_project.group
      puts JSON.pretty_generate(options_project.create)
    else
      puts 'Group was not provided. Users are not supported'
    end
  elsif options.resource == 'deploy_key' && options_deploy_key && options.deploy_key_data
    # create deploy key for the project
    if options_project
      puts JSON.pretty_generate(options_project.deploy_key_data_enable(options_deploy_key.name, options.deploy_key_data, options.deploy_key_push))
    # create deploy key for all projects in group
    elsif options_group
      options_group.projects_group_path.each do |p|
        group_project = GitLabProject.new(p, client)

        puts JSON.pretty_generate(group_project.deploy_key_data_enable(options_deploy_key.name, options.deploy_key_data, options.deploy_key_push))
      end
    else
      puts 'Neither group nor project were provided. Can not create deploy key'
    end
  end
when 'enable'
  # enable deploy key if provided
  if options.deploy_key.is_a?(String) && options.deploy_key
    deploy_key = GitLabDeployKey.new(options.deploy_key, client)

    # for project if specified
    if options_project

    # or for group if specified
    elsif options_group
      options_group.projects_group_path.each do |p|
        group_project = GitLabProject.new(p, client)

        if group_project.deploy_key_check(deploy_key)
          puts JSON.pretty_generate(group_project.deploy_keys) if options.verbose
        else
          puts group_project.deploy_key_enable(deploy_key)
        end
        puts JSON.pretty_generate(group_project.deploy_key_push(deploy_key, options.deploy_key_push)) if options.deploy_key_push
      end
    end
  end
when 'show'
  if options.resource == 'deploy_key'

  elsif options.resource.nil? && options_group
    puts JSON.pretty_generate(options_group.get)
  end
else # list
  if options.resource == 'deploy_key'
    GitLabDeployKey.set_client(client)
    if options_project
      puts JSON.pretty_generate(options_project.deploy_keys)
    else
      puts JSON.pretty_generate(GitLabDeployKey.deploy_keys)
    end
  # list groups
  elsif options.resource.nil?
    GitLabGroup.set_client(client)

    puts JSON.pretty_generate(GitLabGroup.groups)
  end
end
