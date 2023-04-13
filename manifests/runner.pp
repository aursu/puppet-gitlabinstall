# @summary Install and run GitLab Runner
#
# Install and run GitLab Runner using manual
# https://docs.gitlab.com/runner/install/docker.html#option-1-use-local-system-volume-mounts-to-start-the-runner-container
#
# @example
#   include gitlabinstall::runner
class gitlabinstall::runner (
  String  $docker_image         = 'gitlab/gitlab-runner:v15.10.1',
  Boolean $register_runner      = true,
  Optional[String]
          $runner_name          = undef,
  Optional[String]
          $registration_token   = undef,
  Optional[Array[String]]
          $runner_tag_list      = undef,
  Optional[Stdlib::HTTPUrl]
          $gitlab_url           = undef,
  Optional[String]
          $runner_dokcer_image  = 'centos:7',
) inherits gitlabinstall::runner::params {
  $compose_service = $gitlabinstall::runner::params::compose_service
  $compose_project = $gitlabinstall::runner::params::compose_project
  $service_dir     = $gitlabinstall::runner::params::service_dir

  gitlabinstall::runner::service { $compose_service:
    compose_project     => $compose_project,
    docker_image        => $docker_image,
    manage_image        => true,
    runner_dir          => $service_dir,
    register            => $register_runner,
    runner_name         => $runner_name,
    registration_token  => $registration_token,
    runner_tag_list     => $runner_tag_list,
    gitlab_url          => $gitlab_url,
    runner_dokcer_image => $runner_dokcer_image,
  }
}
