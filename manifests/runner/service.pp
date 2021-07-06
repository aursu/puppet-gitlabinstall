# @summary Run GitLab Runner
#
# Run GitLab Runner
#
# @example
#   gitlabinstall::runner::service { 'namevar': }
define gitlabinstall::runner::service (
  String  $compose_service      = $name,
  String  $compose_project      = 'gitlab',
  String  $docker_image         = 'gitlab/gitlab-runner:v14.0.1',
  Boolean $manage_image         = false,
  Optional[Stdlib::Host]
          $docker_host          = undef,
  Optional[Stdlib::IP::Address]
          $docker_ipaddr        = undef,
  Optional[Stdlib::Unixpath]
          $docker_tlsdir        = undef,
  Optional[Stdlib::Unixpath]
          $runner_dir           = undef,
  Boolean $register             = false,
  Optional[String]
          $runner_name          = $name,
  Optional[String]
          $runner_description   = $runner_name,
  Optional[String]
          $registration_token   = undef,
  Optional[Array[String]]
          $runner_tag_list      = undef,
  Boolean $run_untagged         = true,
  Boolean $runner_locked        = false,
  Enum['not_protected', 'ref_protected']
          $runner_access_level  = 'not_protected',
  Optional[Stdlib::HTTPUrl]
          $gitlab_url           = undef,
  Optional[String]
          $authentication_token = undef,
  String  $runner_executor      = 'docker',
  Optional[String]
          $runner_dokcer_image  = undef,
)
{
  include dockerinstall::params
  include gitlabinstall::runner::base

  $service_dir = $gitlabinstall::runner::params::service_dir
  if $runner_dir {
    $service_runner_dir = $runner_dir
  }
  else {
    $service_runner_dir = "${service_dir}/${name}"
    file { $service_runner_dir:
      ensure => directory,
    }
  }

  # Docker host hostname
  if $docker_host {
    $docker_host_name = $docker_host
  }
  else {
    $docker_host_name = $dockerinstall::params::certname
  }

  # docker host tcp:// address for TLS
  $docker_host_tcp = "tcp://${docker_host_name}:2376"

  # configure TLS directory
  if $docker_tlsdir {
    $docker_tlsdir_mount = $docker_tlsdir
  }
  else {
    $docker_tlsdir_mount = $dockerinstall::params::docker_tlsdir
  }

  # Docker host IP address
  if $docker_ipaddr {
    $docker_extra_hosts = [ "${docker_host_name}:${docker_ipaddr}" ]
  }
  else  {
    $docker_extra_hosts = undef
  }

  $persistent_dir = "${service_runner_dir}/config"
  file { $persistent_dir:
    ensure => directory,
  }

  dockerinstall::webservice { $compose_service:
    project_name       => $compose_project,
    service_name       => $compose_service,
    manage_image       => $manage_image,
    docker_image       => $docker_image,
    docker_extra_hosts => $docker_extra_hosts,
    environment        => {
      'DOCKER_TLS_CERTDIR' => '/certs',
      'DOCKER_CERT_PATH'   => '/certs/client',
      'DOCKER_TLS_VERIFY'  => '1',
      'DOCKER_HOST'        => $docker_host_tcp,
    },
    docker_volume      => [
                        '/etc/docker/certs.d:/etc/docker/certs.d',
                        '/var/run/docker.sock:/var/run/docker.sock',
                        "${docker_tlsdir_mount}:/certs/client",
                        "${persistent_dir}:/etc/gitlab-runner",
                      ],
    require            => File[$persistent_dir],
  }

  if $register {
    runner_registration { $runner_name:
      ensure               => present,
      config               => "${persistent_dir}/config.toml",
      description          => $runner_description,
      authentication_token => $authentication_token,
      registration_token   => $registration_token,
      tag_list             => $runner_tag_list,
      run_untagged         => $run_untagged,
      locked               => $runner_locked,
      access_level         => $runner_access_level,
      gitlab_url           => $gitlab_url,
      executor             => $runner_executor,
      docker_image         => $runner_dokcer_image,
      environment          => [
        'DOCKER_CERT_PATH=/certs/client',
        'DOCKER_TLS_VERIFY=1',
        "DOCKER_HOST=${docker_host_tcp}"
      ],
      docker_volume        => [
        '/cache',
        '/etc/docker/certs.d:/etc/docker/certs.d',
        "${docker_tlsdir_mount}:/certs/client",
      ],
      extra_hosts          => $docker_extra_hosts,
    }
  }
}
