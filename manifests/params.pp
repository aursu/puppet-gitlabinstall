# @summary Basic module settings
#
# Basic module settings
#
# @example
#   include gitlabinstall::params
class gitlabinstall::params {
  # use directory defined by http://nginx.org/packages/
  $user_shell = $facts['os']['family'] ? {
    'RedHat' => '/sbin/nologin',
    default  => '/usr/sbin/nologin',
  }
  $user_home = '/var/opt/gitlab/nginx'

  # Try to use static Uid/Gid (official for RedHat is apache/48 and for
  # Debian is www-data/33)
  $user_id = $facts['os']['family'] ? {
    'RedHat' => 48,
    default  => 33,
  }

  $user = $facts['os']['family'] ? {
    'RedHat' => 'apache',
    default  => 'www-data',
  }

  $group_id = $user_id
  $group = $user

  $nginx_cache = '/var/cache/nginx'
  $nginx_log_directory = '/var/log/gitlab/nginx'

  $nginx_proxy_cache = 'gitlab'
  $nginx_proxy_cache_path = {
    "${nginx_cache}/proxy_cache" => {
      keys_zone     => "${nginx_proxy_cache}:10m",
      max_size      => '1g',
      levels        => '1:2',
      use_temp_path => false,
    },
  }

  $gitlab_workhorse_socket = '/var/opt/gitlab/gitlab-workhorse/socket'
  $nginx_upstream_members = {
    'gitlab-workhorse-socket' => {
      server => "unix:${gitlab_workhorse_socket}",
    }
  }

    # hardcode GitLab CE Omnibus installation
    $upstream_edition = 'ce'
    $service_name = 'gitlab-runsvdir'

    # https://docs.gitlab.com/ee/administration/packages/container_registry.html#container-registry-storage-path
    $registry_path = '/var/opt/gitlab/gitlab-rails/shared/registry'
    $registry_dir  = '/var/opt/gitlab/registry'

    # Registry TLS auth key
    $registry_cert_path = "${registry_dir}/gitlab-registry.crt"
    $registry_key_path = '/var/opt/gitlab/gitlab-rails/etc/gitlab-registry.key'

    if $facts['puppet_sslpaths'] {
      $privatekeydir = $facts['puppet_sslpaths']['privatekeydir']['path']
      $certdir       = $facts['puppet_sslpaths']['certdir']['path']
    }
    else {
      # fallback to predefined
      $privatekeydir = '/etc/puppetlabs/puppet/ssl/private_keys'
      $certdir       = '/etc/puppetlabs/puppet/ssl/certs'
    }

    if $facts['clientcert'] {
      $certname = $facts['clientcert']
    }
    else {
      # fallback to fqdn
      $certname = $facts['fqdn']
    }

    $hostprivkey = "${privatekeydir}/${certname}.pem"
    $hostcert    = "${certdir}/${certname}.pem"

    # https://docs.gitlab.com/ee/administration/packages/index.html#changing-the-local-storage-path
    $packages_storage_path = '/var/opt/gitlab/gitlab-rails/shared/packages'

    $backup_path = '/var/opt/gitlab/backups'

    $database_username = 'gitlab'
    $database_name     = 'gitlabhq_production'
    $database_port     = 5432
}
