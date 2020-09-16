require 'json'

Facter.add(:gitlab_auth_token) do
  setcode do
    begin
      content = File.read('/etc/docker/registry/token.json')
      JSON.parse(content)
    rescue JSON::ParserError => e
      Puppet.warning(_('Failed to read token file (%{message})') % { message: e.message })
      nil
    rescue SystemCallError # Errno::ENOENT
      nil
    end
  end
end
