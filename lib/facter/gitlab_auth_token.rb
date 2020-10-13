require 'json'

Facter.add(:gitlab_auth_token) do
  setcode do
    auth_token = {}
    Dir.glob('/etc/docker/registry/*.json').each do |file_name|
      # token name
      token_name = %r{(?<token_name>[^/]+)\.json$}.match(file_name.downcase)[:token_name]
      token_name = (token_name == 'token') ? 'default' : token_name

      begin
        # token raw content
        token_content = File.read(file_name)

        # token JSON data
        token_data = JSON.parse(token_content)
        access_token = token_data['token']
        access_data  = token_data['access']

        # default token only if token name is 'default'
        auth_token['default'] = access_token if token_name == 'default'

        access_data.each do |a|
          # project name
          name = a['name']
          # add slash into project name to reflect URL form and segregate it
          # from 'default' token
          auth_token[name] = access_token if name
        end
      rescue SystemCallError
        next
      rescue JSON::ParserError
        next
      end
    end
    auth_token
  end
end
