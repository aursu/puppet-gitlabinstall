# @summary GitLab installation management
#
# GitLab installation management
#
# @example
#   include gitlabinstall::gitlab
#
# @param external_url
#   Configuring the external URL for GitLab
#   see [Configuring the external URL for GitLab](https://docs.gitlab.com/omnibus/settings/configuration.html#configuring-the-external-url-for-gitlab)
#
# @param gitlab_package_ensure
#   RPM package version. For example, 13.3.2-ce.0.el7 (see https://packages.gitlab.com/gitlab/gitlab-ce)
#
# @param log_dir
#   Log directory to manage
#
# @param external_postgresql_service
#   Using a non-packaged PostgreSQL database management server
#   see [Using a non-packaged PostgreSQL database management server](https://docs.gitlab.com/omnibus/settings/database.html#using-a-non-packaged-postgresql-database-management-server)
#
# @param registry_api_url
#   This is the Registry URL used internally that users do not need to interact with
#   it is gitlab_rails['registry_api_url'] setting in /etc/gitlab/gitlab.rb
#
# @param registry_host
#   Registry endpoint without the scheme, the address that gets shown to the end user.
#   it is gitlab_rails['registry_host'] setting in /etc/gitlab/gitlab.rb
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
# @param packages_enabled
#   Enabling the Packages feature
#   see [GitLab Package Registry administration](https://docs.gitlab.com/ee/administration/packages/)
#
# @param packages_storage_path
#   Local storage path for packages for Omnibus GitLab installation
#
# @param ssl_cert
#   Content of x509 certificate to use for GitLab TLS setup
#
# @parma ssl_key
#   Content of RSA private key to use for GitLab TLS setup
#
class gitlabinstall::gitlab (
  Stdlib::HTTPUrl
            $external_url                = $gitlabinstall::external_url,
  String[8] $database_password           = $gitlabinstall::database_password,

  String    $gitlab_package_ensure       = $gitlabinstall::gitlab_package_ensure,

  String    $log_dir                     = '/var/log/gitlab',

  # https://docs.gitlab.com/omnibus/settings/database.html#using-a-non-packaged-postgresql-database-management-server
  Boolean   $external_postgresql_service = $gitlabinstall::external_postgresql_service,
  Boolean   $manage_postgresql_core      = $gitlabinstall::manage_postgresql_core,
  String    $database_host               = $gitlabinstall::database_host,
  Variant[Integer, Pattern[/^[0-9]+$/]]
            $database_port               = $gitlabinstall::params::database_port,
  String    $database_username           = $gitlabinstall::params::database_username,
  String    $database_name               = $gitlabinstall::params::database_name,

  # https://docs.gitlab.com/omnibus/settings/nginx.html#using-a-non-bundled-web-server
  Boolean   $non_bundled_web_server      = $gitlabinstall::non_bundled_web_server,
  Boolean   $manage_nginx_core           = true,
  Boolean   $manage_cert_data            = true,
  Optional[String]
            $cert_identity               = undef,
  Optional[String]
            $ssl_cert                    = undef,
  Optional[String]
            $ssl_key                     = undef,
  String    $gitlab_rails_host           = 'localhost',
  Integer   $gitlab_rails_port           = 8080,
  Boolean   $monitoring                  = false,

  # External Registry (https://docs.gitlab.com/ce/administration/container_registry.html#disable-container-registry-but-use-gitlab-as-an-auth-endpoint)
  # See https://docs.gitlab.com/omnibus/architecture/registry/
  Boolean   $external_registry_service   = $gitlabinstall::external_registry_service,
  # gitlab_rails['registry_host']
  Optional[Stdlib::Fqdn]
            $registry_host               = $gitlabinstall::registry_host,
  # gitlab_rails['registry_port']
  Integer   $registry_port               = $gitlabinstall::registry_port,
  # gitlab_rails['registry_api_url']
  Stdlib::HTTPUrl
            $registry_api_url            = $gitlabinstall::registry_api_url,

  # TLS authentication to registry
  # gitlab_rails['registry_key_path'] = "/custom/path/to/registry-key.key"
  Optional[Stdlib::Unixpath]
            $registry_key_path           = undef,
  # registry['internal_key'] = "---BEGIN RSA PRIVATE KEY---\nMIIEpQIBAA\n"
  Optional[String]
            $registry_internal_key       = undef,

  # Mount points for GitLab (/dev)
  Optional[Stdlib::Unixpath]
            $mnt_distro                  = undef,
  String    $mnt_distro_fstype           = 'ext4',
  Optional[Stdlib::Unixpath]
            $mnt_data                    = undef,
  String    $mnt_data_fstype             = 'ext4',

  # Packages
  # https://docs.gitlab.com/ee/administration/packages/index.html
  Boolean   $packages_enabled            = true,

  Optional[Stdlib::Unixpath]
            $packages_storage_path       = $gitlabinstall::params::packages_storage_path,
)  inherits gitlabinstall::params
{
  $upstream_edition = $gitlabinstall::params::upstream_edition
  $service_name     = $gitlabinstall::params::service_name
  $hostprivkey      = $gitlabinstall::params::hostprivkey
  $user_id          = $gitlabinstall::params::user_id
  $user             = $gitlabinstall::params::user
  $group_id         = $gitlabinstall::params::group_id
  $group            = $gitlabinstall::params::group
  $user_home        = $gitlabinstall::params::user_home
  $user_shell       = $gitlabinstall::params::user_shell

  # extract GitLab hostname from its sexternal_url (see Omnibus installation
  # manual for external_url description)
  $urldata = split($external_url, '/')
  if $urldata[0] in ['http:', 'https:', ''] and $urldata[1] == '' {
    $server_name = $urldata[2]
  }
  else {
    $server_name = $urldata[0]
  }

  $gitlab_package_ensure_data = split($gitlab_package_ensure, '-')
  $gitlab_version = $gitlab_package_ensure_data[0]

  class { 'gitlabinstall::ssl':
    manage_cert_data => $manage_cert_data,
    server_name      => $server_name,
    cert_identity    => $cert_identity,
    ssl_cert         => $ssl_cert,
    ssl_key          => $ssl_key,
  }

  $ssl_cert_path  = $gitlabinstall::ssl::ssl_cert_path
  $ssl_key_path   = $gitlabinstall::ssl::ssl_key_path
  $cert_lookupkey = $gitlabinstall::ssl::cert_lookupkey

  # postgresql
  if $external_postgresql_service {
    class { 'gitlabinstall::postgres':
      manage_service    => $manage_postgresql_core,
      database_password => $database_password,
      database_username => $database_username,
      database_name     => $database_name,
      before            => Class['gitlab'],
    }

    $postgresql = {
      enable => false,
    }

    $gitlab_rails = {
      db_adapter  => 'postgresql',
      db_encoding => 'utf8',
      db_host     => $database_host,
      db_port     => $database_port,
      db_username => $database_username,
      db_password => $database_password,
      db_database => $database_name,
    }
  }
  else {
    $postgresql = {}
    $gitlab_rails = {}
  }

  # nginx
  if $non_bundled_web_server {
    class { 'gitlabinstall::nginx':
      manage_service => $manage_nginx_core,
      server_name    => $server_name,
      ssl            => true,
      ssl_cert_path  => $ssl_cert_path,
      ssl_key_path   => $ssl_key_path,
      require        => Class['gitlab'],
    }

    $nginx = {
      enable => false,
    }

    $web_server = {
      username => $user,
      home     => $user_home,
      shell    => $user_shell,
      uid      => $user_id,
      group    => $group,
      gid      => $group_id,
    }

    if $manage_cert_data {
      Tlsinfo::Certpair[$cert_lookupkey] ~> Class['nginx::service']
    }
  }
  else {
    $nginx = {
      'redirect_http_to_https' => true,
      # see [Change the default port and the SSL certificate locations](https://docs.gitlab.com/omnibus/settings/nginx.html#change-the-default-port-and-the-ssl-certificate-locations)
      'ssl_certificate'        => $ssl_cert_path,
      'ssl_certificate_key'    => $ssl_key_path,
    }
    $web_server = {}
  }

  # GitLab Unicorn default TCP socket is localhost:8080
  if $gitlab_rails_host == 'localhost' and $gitlab_rails_port == 8080 {
    $unicorn = {}
    $puma = {}
    $gitlab_workhorse = {}
  }
  else {
    # https://docs.gitlab.com/omnibus/settings/puma.html#converting-unicorn-settings-to-puma
    # Starting with GitLab 13.0, Puma is the default web server and Unicorn has been disabled by default.
    if versioncmp($gitlab_version, '13.0') >= 0 {
      $unicorn = {}
      $puma = {
        listen => $gitlab_rails_host,
        port   => $gitlab_rails_port,
      }
    }
    else {
      $unicorn = {
        listen => $gitlab_rails_host,
        port   => $gitlab_rails_port,
      }
      $puma = {}
    }

    $gitlab_workhorse = {
      auth_backend => "http://${gitlab_rails_host}:${gitlab_rails_port}",
    }
  }

  # internal monitoring
  if $monitoring {
    $prometheus_monitoring_enable = undef
    $sidekiq = {}
  }
  else {
    $prometheus_monitoring_enable = false
    $sidekiq = {
      metrics_enabled => false,
    }
  }

  # Docker registry
  # see https://docs.gitlab.com/ee/administration/packages/container_registry.html#use-an-external-container-registry-with-gitlab-as-an-auth-endpoint
  if $external_registry_service {
    unless $registry_host {
      fail('You must supply registry_host parameter to gitlabinstall::gitlab')
    }

    # Client private key for TLS authentication between GitLab and Registry
    # GitLab is client for Registry
    if $registry_key_path {
      $clientauth_key = $registry_key_path
    }
    else {
      # default key location is /var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key
      $clientauth_key = $gitlabinstall::params::registry_key_path
    }

    if $registry_internal_key {
      file { $clientauth_key:
        content => $registry_internal_key,
        require => Class['gitlab'],
      }

      $gitlab_registry = {
        'internal_key' => $registry_internal_key,
      }
    }
    else {
      file { $clientauth_key:
        source  => "file://${hostprivkey}",
        require => Class['gitlab'],
      }

      $gitlab_registry = {}
    }

    $gitlab_rails_registry = {
      'registry_enabled'  => true,
      'registry_host'     => $registry_host,
      'registry_port'     => $registry_port,
      'registry_api_url'  => $registry_api_url,
      # This setting needs to be set the same between Registry and GitLab.
      # match to registry environment REGISTRY_AUTH_TOKEN_ISSUER
      'registry_issuer'   => 'omnibus-gitlab-issuer',
      'registry_key_path' => $clientauth_key,
    }

    $registry_path = $gitlabinstall::params::registry_path

    # GitLab backup could be broken due to missed folder
    file { $registry_path:
      ensure => directory,
      owner  => 'git',
      group  => 'git',
    }
  }
  else {
    $gitlab_registry = {}
    $gitlab_rails_registry = {}
  }

  # Package Registry (Moved to GitLab Core in 13.3)
  # TODO: add storage management (directory path, mount)
  if $packages_enabled {
    $gitlab_rails_packages = {
      'packages_enabled'      => true,
      'packages_storage_path' => $packages_storage_path,
    }
  }
  else {
    $gitlab_rails_packages = {}
  }

  file { $log_dir:
    ensure => directory,
  }

  class { 'gitlab':
    package_ensure               => $gitlab_package_ensure,
    manage_upstream_edition      => $upstream_edition,
    service_manage               => true,
    service_name                 => $service_name,
    external_url                 => $external_url,
    postgresql                   => $postgresql,
    gitlab_rails                 => $gitlab_rails +
                                    $gitlab_rails_registry +
                                    $gitlab_rails_packages,
    registry                     => $gitlab_registry,
    nginx                        => $nginx,
    web_server                   => $web_server,
    unicorn                      => $unicorn,
    puma                         => $puma,
    gitlab_workhorse             => $gitlab_workhorse,
    prometheus_monitoring_enable => $prometheus_monitoring_enable,
    sidekiq                      => $sidekiq,
  }

  # mount points for GitLab distro & data files
  if $mnt_distro {
    exec { '/usr/bin/mkdir -p /opt/gitlab':
      creates => '/opt/gitlab',
      before  => Mount['/opt/gitlab']
    }
    mount { '/opt/gitlab':
      ensure => 'mounted',
      device => $mnt_distro,
      fstype => $mnt_distro_fstype,
      before => Class['gitlab'],
    }
  }

  if $mnt_data {
    exec { '/usr/bin/mkdir -p /var/opt/gitlab':
      creates => '/var/opt/gitlab',
      before  => Mount['/var/opt/gitlab']
    }
    mount { '/var/opt/gitlab':
      ensure => 'mounted',
      device => $mnt_data,
      fstype => $mnt_data_fstype,
      before => Class['gitlab'],
    }
  }

  # TODO: backup (https://docs.gitlab.com/ee/raketasks/backup_restore.html)
  # 0 3 * * * /opt/gitlab/bin/gitlab-rake gitlab:backup:create CRON=1
  #
  # At the very minimum, you must backup (For Omnibus):
  # /etc/gitlab/gitlab-secrets.json
  # /etc/gitlab/gitlab.rb
  #
  # You may also want to back up any TLS keys and certificates:
  # /etc/ssh/ssh_host_*
  #
  # All configuration for Omnibus GitLab is stored in /etc/gitlab. To backup
  # your configuration, just run sudo gitlab-ctl backup-etc. It will create a
  # tar archive in /etc/gitlab/config_backup/. Directory and backup files
  # will be readable only to root.
  #
  # First make sure your backup tar file is in the backup directory described
  # in the gitlab.rb configuration gitlab_rails['backup_path']. The default
  # is /var/opt/gitlab/backups. It needs to be owned by the git user.
  # https://docs.gitlab.com/ee/raketasks/backup_restore.html#restore-for-omnibus-gitlab-installations

  # 0 */4 * * * /usr/bin/find /var/opt/gitlab/backups -mmin +7200 -delete
  # 0 3 * * * /opt/gitlab/bin/gitlab-rake gitlab:backup:create CRON=1
}
