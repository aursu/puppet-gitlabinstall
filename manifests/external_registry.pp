# @summary External registry integration into GitLab
#
# External registry integration into GitLab
#
# @example
#   include gitlabinstall::external_registry
#
# @param registry_host
#   Registry endpoint without the scheme, the address that gets shown to the end user.
#   it is gitlab_rails['registry_host'] setting in /etc/gitlab/gitlab.rb
#
# @param registry_api_url
#   This is the Registry URL used internally that users do not need to interact with
#   it is gitlab_rails['registry_api_url'] setting in /etc/gitlab/gitlab.rb
#
# @param registry_port
#   Registry endpoint port, visible to the end user
#   it is gitlab_rails['registry_port'] setting in /etc/gitlab/gitlab.rb
#
# @param registry_internal_key
#   Contents of the key that GitLab uses to sign the tokens.
#   It is registry['internal_key'] setting in /etc/gitlab/gitlab.rb
#   A certificate-key pair is required for GitLab and the external container
#   registry to communicate securely. You will need to create a certificate-key
#   pair, configuring the external container registry with the public certificate
#   and configuring GitLab with the private key
#
# @param registry_key_path
#   Path to the key that matches the certificate on the Registry side.
#   It is gitlab_rails['registry_key_path'] setting in /etc/gitlab/gitlab.rb
#   Custom file for Omnibus GitLab to write the contents of
#   registry['internal_key'] to. The file specified at `registry_key_path` gets
#   populated with the content specified by `internal_key`, each time reconfigure
#   is executed. If no file is specified, Omnibus GitLab will default it to
#   `/var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key` and will populate it.
#
# @param registry_internal_certificate
#   Contents of the certificate that GitLab uses to sign the tokens. This
#   parameter allows to setup custom certificate into file system path
#   (`registry_cert_path`) or export to Puppet DB. It will not influence on
#   GitLab configuration (there is no support to embedded registry configuration
#   in this moodule)
#
# @param registry_cert_path
#   This is the path where `registry_internal_certificate` contents will be
#   written to disk.
#   default certificate location is /var/opt/gitlab/registry/gitlab-registry.crt
#
# @param registry_cert_export
#   Whether to write certificate content intoo local file system or export it to
#   Puppet DB
#
# @param token_username
#   Username to use for default JWT auth token (as subject field). This token
#   will be generated and stored into file `/etc/docker/registry/token.json`
#   and available through custom fact `gitlab_auth_token`
#
# @param token_expire_time
#   Expiration time for default JWT token. Could be unix timestamp or string
#   representation of a time (which could be parsed by ruby function Time.parse)
#   Default expiration time is
#
# @param token_expire_threshold
#   Threshold for expiration time in seconds. If expiration time is less then
#   current time plus threshold than Puppet will generate new auth token.
#   Default threshold is 600 seconds
#
class gitlabinstall::external_registry (
  # gitlab_rails['registry_host']
  Stdlib::Fqdn
          $registry_host                 = $gitlabinstall::registry_host,
  # gitlab_rails['registry_port']
  Integer $registry_port                 = $gitlabinstall::registry_port,
  # gitlab_rails['registry_api_url']
  Stdlib::HTTPUrl
          $registry_api_url              = $gitlabinstall::registry_api_url,

  # registry['internal_key'] = "---BEGIN RSA PRIVATE KEY---\nMIIEpQIBAA\n"
  Optional[String]
          $registry_internal_key         = undef,

  Optional[String]
          $registry_internal_certificate = undef,
  Optional[Stdlib::Unixpath]
          $registry_cert_path            = undef,

  Boolean $registry_cert_export          = true,
  # Token settings
  String  $token_username                = 'registry-bot',
  Optional[String]
          $token_expire_time             = undef,
  Optional[Integer]
          $token_expire_threshold        = undef,
) inherits gitlabinstall::params
{
  # Docker registry
  # see https://docs.gitlab.com/ee/administration/packages/container_registry.html#use-an-external-container-registry-with-gitlab-as-an-auth-endpoint

  $registry_path = $gitlabinstall::params::registry_path
  $registry_dir  = $gitlabinstall::params::registry_dir
  $hostprivkey   = $gitlabinstall::params::hostprivkey
  $server_name   = $gitlabinstall::server_name

  # Token authentication to registry
  # See https://docs.gitlab.com/omnibus/architecture/registry/#configuring-registry
  # gitlab_rails['registry_key_path'] = "/custom/path/to/registry-key.key"
  $registry_key_path = $gitlabinstall::params::registry_key_path

  if $registry_internal_key {
    file { 'internal_key':
      path    => $registry_key_path,
      content => $registry_internal_key,
    }

    $gitlab_registry = {
      'internal_key' => $registry_internal_key,
    }
  }
  else {
    file { 'internal_key':
      path   => $registry_key_path,
      source => "file://${hostprivkey}",
    }

    $gitlab_registry = {}
  }

  class { 'dockerinstall::registry::gitlab':
    registry_cert_export          => $registry_cert_export,
    registry_internal_certificate => $registry_internal_certificate,
    gitlab_host                   => $server_name,
  }

  # GitLab backup could be broken due to missed folder
  file {
    default:
      ensure  => directory,
    ;
    $registry_path:
      owner => 'git',
      group => 'git',
    ;
    $registry_dir:
      owner => 'root',
      group => 'root',
    ;
  }

  $gitlab_rails = {
    'registry_enabled'  => true,
    'registry_host'     => $registry_host,
    'registry_port'     => $registry_port,
    'registry_api_url'  => $registry_api_url,
    # This setting needs to be set the same between Registry and GitLab.
    # match to registry environment REGISTRY_AUTH_TOKEN_ISSUER
    'registry_issuer'   => 'omnibus-gitlab-issuer',
    'registry_key_path' => $registry_key_path,
  }

  package {
    ['jwt', 'base32']:
      ensure   => 'installed',
      provider => 'puppet_gem',
    ;
  }

  registry_token { 'default':
    target      => 'token.json',
    audience    => 'container_registry',
    subject     => $token_username,
    issuer      => 'omnibus-gitlab-issuer',
    expire_time => $token_expire_time,
    threshold   => $token_expire_threshold,
  }
}
