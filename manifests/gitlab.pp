# @summary GitLab installation management
#
# GitLab installation management
#
# @example
#   include gitlabinstall::gitlab
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
# @param ssl_key
#   Content of RSA private key to use for GitLab TLS setup
#
# @param repo_sslverify
#   Set `sslverify` flag for Omnibus GitLab Yum repository
#
# @param monitoring_whitelist
#   GitLab provides liveness and readiness probes to indicate service health.
#   To access monitoring resources, the requesting client IP needs to be
#   included in a whitelist.
#   See https://docs.gitlab.com/ee/administration/monitoring/ip_whitelist.html
#
# @param database_upgrade
#   Avoid Postgres resources management when PostgreSQL is updating
#
class gitlabinstall::gitlab (
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
  Optional[Integer[0,1]]
            $repo_sslverify              = undef,
  Array[Stdlib::IP::Address]
            $monitoring_whitelist        = $gitlabinstall::monitoring_whitelist,
  Boolean   $ldap_enabled                = $gitlabinstall::ldap_enabled,

  # SMTP settings
  Boolean   $smtp_enabled                 = $gitlabinstall::smtp_enabled,
  Boolean   $database_upgrade             = $gitlabinstall::database_upgrade,
)  inherits gitlabinstall::params
{
  $upstream_edition = $gitlabinstall::params::upstream_edition
  $service_name     = $gitlabinstall::params::service_name
  $user_id          = $gitlabinstall::params::user_id
  $user             = $gitlabinstall::params::user
  $group_id         = $gitlabinstall::params::group_id
  $group            = $gitlabinstall::params::group
  $user_home        = $gitlabinstall::params::user_home
  $user_shell       = $gitlabinstall::params::user_shell
  $certname         = $gitlabinstall::params::certname
  $hostcert         = $gitlabinstall::params::hostcert
  $listen_addr      = $gitlabinstall::params::gitlab_workhorse_socket

  $external_url = $gitlabinstall::external_url
  $server_name  = $gitlabinstall::server_name

  $gitlab_package_ensure_data = split($gitlab_package_ensure, '-')
  $gitlab_version = $gitlab_package_ensure_data[0]

  # https://docs.gitlab.com/omnibus/update/gitlab_13_changes.html#default-workhorse-listen-socket-moved
  if versioncmp($gitlab_version, '13.5') >= 0 {
    $gitlab_workhorse_socket = {
      listen_addr => $listen_addr,
    }

    if $facts['os']['selinux']['enabled'] {
      exec { "restorecon ${listen_addr}":
        path        => '/sbin:/usr/sbin',
        refreshonly => true,
        subscribe   => Package['gitlab-omnibus'],
      }
    }
  }
  else {
    $gitlab_workhorse_socket = {}
  }

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
      database_upgrade  => $database_upgrade,
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

  if $external_registry_service {
    include gitlabinstall::external_registry

    $gitlab_registry       = $gitlabinstall::external_registry::gitlab_registry
    $gitlab_rails_registry = $gitlabinstall::external_registry::gitlab_rails

    Class['gitlab'] -> Class['gitlabinstall::external_registry']
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

  if $monitoring_whitelist[0] {
    $gitlab_rails_monitoring_whitelist = {
      'monitoring_whitelist' => $monitoring_whitelist,
    }
  }
  else {
    $gitlab_rails_monitoring_whitelist = {}
  }

  if $ldap_enabled {
    include gitlabinstall::ldap

    $gitlab_rails_ldap = $gitlabinstall::ldap::gitlab_rails
  }
  else {
    $gitlab_rails_ldap = {}
  }

  if $smtp_enabled {
    include gitlabinstall::smtp

    $gitlab_rails_smtp = $gitlabinstall::smtp::gitlab_rails
  }
  else {
    $gitlab_rails_smtp = {}
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
                                    $gitlab_rails_packages +
                                    $gitlab_rails_monitoring_whitelist +
                                    $gitlab_rails_ldap +
                                    $gitlab_rails_smtp,
    registry                     => $gitlab_registry,
    nginx                        => $nginx,
    web_server                   => $web_server,
    unicorn                      => $unicorn,
    puma                         => $puma,
    gitlab_workhorse             => $gitlab_workhorse +
                                    $gitlab_workhorse_socket,
    prometheus_monitoring_enable => $prometheus_monitoring_enable,
    sidekiq                      => $sidekiq,
  }

  $repo_name = "gitlab_official_${upstream_edition}"

  if $repo_sslverify {
    Yumrepo <| title == $repo_name |> {
      sslverify => $repo_sslverify,
    }
  }

  file { "/etc/yum.repos.d/${repo_name}.repo":
    mode => '0600',
  }

  # small cleanup in case of preceding manual uninstallation
  # to avoid https://docs.gitlab.com/omnibus/common_installation_problems/#reconfigure-freezes-at-ruby_blocksupervise_redis_sleep-action-run
  if $upstream_edition in ['ce', 'ee'] and $service_name == 'gitlab-runsvdir' {
    [ '/usr/lib/systemd/system/gitlab-runsvdir.service',
      '/etc/systemd/system/basic.target.wants/gitlab-runsvdir.service'].each |$unit| {
      exec { "rm -f ${unit}":
        refreshonly => true,
        onlyif      => "test -f ${unit}",
        subscribe   => Package['gitlab-omnibus'],
        notify      => Exec['gitlab_reconfigure'],
        path        => '/bin:/usr/bin',
      }
    }
  }

  # run db:migrate after reconfigure
  # see https://forum.gitlab.com/t/upgrading-from-13-9-4-to-13-10-0-results-in-an-error-500/50685/2
  exec { 'gitlab-rake db:migrate':
    path        => '/opt/gitlab/bin:/bin:/usr/bin',
    refreshonly => true,
    subscribe   => [
      Package['gitlab-omnibus'],
      Exec['gitlab_reconfigure'],
    ],
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
