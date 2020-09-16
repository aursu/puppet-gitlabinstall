require 'openssl'
require 'jwt'

# default token TTL is 365 days
#   gitlab-rake "gitlab:container_registry:token[username]"
# it could be defined from command line (for example, TTL = 10 days for user username)
#   gitlab-rake "gitlab:container_registry:token[username,10]"

namespace :gitlab do
  namespace :container_registry do
    desc 'GitLab | Container Registry | TokenDecrypt'
    task :token_decrypt, [:token] => :gitlab_environment do |_t, args|
      token_decrypt(args.token)
    end

    desc 'GitLab | Container Registry | Token'
    task :token, [:username, :period] => :gitlab_environment do |_t, args|
      period = args.period ? args.period.to_i : 365
      token(args.username, period)
    end

    def token_expire_at(days)
      Time.current + (days * 24 * 60 * 60)
    end

    def authorized_token(username, period)
      registry = Gitlab.config.registry

      JSONWebToken::RSAToken.new(registry.key).tap do |token|
        token.issuer = registry.issuer
        token.audience = 'container_registry'
        token.subject = username
        token.expire_time = token_expire_at(period)
        token[:access] = []
      end
    end

    def token_decrypt(token)
      registry = Gitlab.config.registry

      unless registry.enabled && registry.api_url.presence
        puts 'Registry is not enabled or registry api url is not present.'.color(:yellow)
        return
      end

      pkey = File.read(registry.key)
      secret = OpenSSL::PKey::RSA.new(pkey).public_key

      puts ::JWT.decode(token, secret, true, algorithm: 'RS256')
    end

    def token(username, period)
      registry_config = Gitlab.config.registry

      unless registry_config.enabled && registry_config.api_url.presence
        puts 'Registry is not enabled or registry api url is not present.'.color(:yellow)
        return
      end

      puts authorized_token(username, period).encoded
    end
  end
end
