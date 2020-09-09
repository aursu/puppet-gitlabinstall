# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include gitlabinstall::nginx
#
# @param manage_service
#   Whether to manage Nginx core settings or not
#
# @param global_proxy_settings
#   Whether to enable global proxy cache settings or not. These settings will
#   reside in Nginx http context (therefore they are global). These settings
#   could be applied only if Nginx core is managed not here (so `manage_service`
#   is false)
#
# @param monitoring_whitelist
#   GitLab provides liveness and readiness probes to indicate service health.
#   To access monitoring resources, the requesting client IP needs to be
#   included in a whitelist.
#   See https://docs.gitlab.com/ee/administration/monitoring/ip_whitelist.html
#
class gitlabinstall::nginx (
  Boolean $manage_service        = $gitlabinstall::manage_nginx_core,
  Boolean $global_proxy_settings = true,
  String  $daemon_user           = $gitlabinstall::params::user,
  Integer $daemon_user_id        = $gitlabinstall::params::user_id,
  String  $daemon_group          = $gitlabinstall::params::group,
  Integer $daemon_group_id       = $gitlabinstall::params::group_id,
  String  $nginx_user_home       = $gitlabinstall::params::user_home,
  String  $web_server_user_shell = $gitlabinstall::params::user_shell,
  Boolean $ssl                   = false,
  Optional[String]
          $ssl_cert_path         = undef,
  Optional[String]
          $ssl_key_path          = undef,
  Boolean $manage_document_root  = false,
  Array[Stdlib::IP::Address]
          $monitoring_whitelist  = $gitlabinstall::monitoring_whitelist,
) inherits gitlabinstall::params
{
  $external_url = $gitlabinstall::external_url
  $server_name  = $gitlabinstall::server_name

  # Relative URL  extracted from External URL
  # '' for GitLab External URL 'http://gitlab.domain.tld' or 'http://gitlab.domain.tld/'
  # '/folder' for GitLab External URL 'http://gitlab.domain.tld/folder' or 'http://gitlab.domain.tld/folder/any'
  $relative_url = $gitlabinstall::relative_url

  # URL path extracted from External URL
  # '/' for GitLab External URL 'http://gitlab.domain.tld' or 'http://gitlab.domain.tld/'
  # '/folder' for GitLab External URL 'http://gitlab.domain.tld/folder' or 'http://gitlab.domain.tld/folder/any'
  $server_path  = $gitlabinstall::server_path

  $nginx_log_directory     = $gitlabinstall::params::nginx_log_directory
  $nginx_proxy_cache       = $gitlabinstall::params::nginx_proxy_cache
  $nginx_proxy_cache_path  = $gitlabinstall::params::nginx_proxy_cache_path
  $nginx_upstream_members  = $gitlabinstall::params::nginx_upstream_members
  $gitlab_workhorse_socket = $gitlabinstall::params::gitlab_workhorse_socket

  # if SSL enabled - both certificate and key must be provided
  if $ssl and !($ssl_cert_path and $ssl_key_path) {
      fail('SSL certificate path and/or SSL private key path not provided')
  }

  if $manage_service {
      class { 'lsys::nginx':
          daemon_user           => $daemon_user,
          daemon_user_id        => $daemon_user_id,
          daemon_group          => $daemon_group,
          daemon_group_id       => $daemon_group_id,
          nginx_user_home       => $nginx_user_home,
          web_server_user_shell => $web_server_user_shell,
          proxy_cache           => $nginx_proxy_cache,
          proxy_cache_path      => $nginx_proxy_cache_path,
          nginx_log_directory   => $nginx_log_directory,
          nginx_lib_directory   => '/var/lib/nginx',
          manage_document_root  => $manage_document_root,
          global_ssl_redirect   => true,
      }
      File[$nginx_log_directory] -> Nginx::Resource::Server['gitlab-http']
  }
  else {
    if $global_proxy_settings {
      nginx::resource::config { '98-gitlab-global-proxy':
        template => 'gitlabinstall/nginx/conf.d/gitlab-global-proxy.conf.erb',
        options  => {
          proxy_cache      => $nginx_proxy_cache,
          proxy_cache_path => $nginx_proxy_cache_path,
        }
      }
    }
  }

  # additional Nginx settings for filtering GitLab tokens from access logs
  nginx::resource::config { '99-gitlab-logging':
      template => 'gitlabinstall/nginx/conf.d/gitlab-logging.conf.erb',
  }

  # Nginx upstream for GitLab Workhorse socket
  nginx::resource::upstream { 'gitlab-workhorse':
      members => $nginx_upstream_members,
  }

  if $facts['selinux'] {
      selinux::fcontext { $gitlab_workhorse_socket:
          filetype => 's',
          seltype  => 'httpd_var_run_t',
      }
      selinux::exec_restorecon { $gitlab_workhorse_socket:
          refreshonly => false,
          unless      => "/bin/ls -Z ${gitlab_workhorse_socket} | /bin/grep -q httpd_var_run_t",
          onlyif      => "/bin/test -e ${gitlab_workhorse_socket}",
          subscribe   => Selinux::Fcontext[$gitlab_workhorse_socket]
      }
  }

  # Override global gzip settings
  $gzip = true
  $gzip_static = true
  $gzip_comp_level = 2
  $gzip_http_version = '1.1'
  $gzip_vary = true
  $gzip_disable = 'msie6'
  $gzip_min_length = 250
  $gzip_proxied = ['no-cache', 'no-store', 'private', 'expired', 'auth']
  $gzip_types = [
      'text/plain',
      'text/css',
      'text/xml',
      'text/javascript',
      'application/x-javascript',
      'application/json',
      'application/xml',
      'application/xml+rss'
  ]

  # https://github.com/gitlabhq/gitlabhq/issues/694
  # Some requests take more than 30 seconds.
  $proxy_read_timeout = 3600
  $proxy_connect_timeout = 300
  $proxy_redirect = 'off'
  $proxy_http_version = '1.1'
  $proxy_set_header = [
      'Host $http_host_with_default',
      'X-Real-IP $remote_addr',
      'X-Forwarded-For $proxy_add_x_forwarded_for',
      'Upgrade $http_upgrade',
      'Connection $connection_upgrade',
      'X-Forwarded-Proto $scheme',
      'X-Forwarded-Ssl on'
  ]

  # if SSL enabled - use SSL only
  if $ssl {
      $listen_port = 443
  }
  else {
      $listen_port = 80
  }

  $locations_git = {
    '~ (.git/git-receive-pack$|.git/gitlab-lfs/objects|.git/info/lfs/objects/batch$)' => {
        proxy_request_buffering => 'off',
    },
  }

  if $monitoring_whitelist[0] {
    # https://docs.gitlab.com/ee/user/admin_area/monitoring/health_check.html
    $locations_health = {
      '/error.txt' => {
        proxy  => undef,
        return => "500 'nginx returned \$status when communicating with gitlab-workhorse\n'",
      },
      '/error.json' => {
        proxy  => undef,
        return => "500 '{\"error\":\"nginx returned \$status when communicating with gitlab-workhorse\",\"status\":\$status}\n'",
      },
      "= ${relative_url}/-/health" => {
        error_pages => {
          '404 500 502' => '/error.txt',
        }
      },
      "= ${relative_url}/-/readiness" => {
        error_pages => {
          '404 500 502' => '/error.json',
        }
      },
      "= ${relative_url}/-/liveness" => {
        error_pages => {
          '404 500 502' => '/error.json',
        }
      },
    }
  }
  else {
    $locations_health = {}
  }

  $locations_default = {
    $server_path                         => {
    },
    "${relative_url}/assets"             => {
        proxy_cache => 'gitlab',
    },
    '~ ^/(404|500|502)(-custom)?\.html$' => {
        internal => true,
        proxy    => undef,
        www_root => '/opt/gitlab/embedded/service/gitlab-rails/public',
    },
  }

  # setup GitLab nginx main config
  nginx::resource::server { 'gitlab-http':
    ssl                       => $ssl,
    http2                     => $ssl,
    ssl_cert                  => $ssl_cert_path,
    ssl_key                   => $ssl_key_path,
    ssl_session_timeout       => '1d',
    ssl_cache                 => 'shared:SSL:50m',
    ssl_prefer_server_ciphers => true,
    ssl_protocols             => 'TLSv1.2',
    ssl_ciphers               => 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256', # lint:ignore:140chars
    ssl_stapling              => true,
    ssl_stapling_verify       => true,
    listen_ip                 => '*',
    listen_port               => $listen_port,
    server_name               => [
        $server_name,
    ],
    # Increase this if you want to upload large attachments
    # Or if you want to accept large git objects over http
    client_max_body_size      => 0,
    # HSTS Config
    # https://www.nginx.com/blog/http-strict-transport-security-hsts-and-nginx/
    add_header                => {
        'Strict-Transport-Security' => 'max-age=31536000',
    },
    # Individual nginx logs for this GitLab vhost
    access_log                => "${nginx_log_directory}/gitlab_access.log",
    format_log                => 'gitlab_access',
    error_log                 => "${nginx_log_directory}/gitlab_error.log",
    raw_prepend               => [
        template('gitlabinstall/nginx/chunks/default-host.erb'),
        template('nginx/conf.d/gzip.conf.erb'),
        template('nginx/conf.d/proxy.conf.erb'),
    ],

    locations                 => $locations_git +
                                $locations_health +
                                $locations_default,

    locations_defaults        => {
        proxy       => 'http://gitlab-workhorse',
        proxy_cache => 'off',
    },
    error_pages               => {
        404 => '/404.html',
        500 => '/500.html',
        502 => '/502.html',
    },
    use_default_location      => false,
  }
}
