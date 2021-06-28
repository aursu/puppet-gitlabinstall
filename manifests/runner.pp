# @summary Install and run GitLab Runner
#
# Install and run GitLab Runner using manual
# https://docs.gitlab.com/runner/install/docker.html#option-1-use-local-system-volume-mounts-to-start-the-runner-container
#
# @example
#   include gitlabinstall::runner
class gitlabinstall::runner (
  String  $docker_image = 'gitlab/gitlab-runner:v14.0.1',
) inherits gitlabinstall::runner::params
{
  $compose_service = $gitlabinstall::runner::params::compose_service
  $compose_project = $gitlabinstall::runner::params::compose_project
  $service_dir     = $gitlabinstall::runner::params::service_dir

  gitlabinstall::runner::service { $compose_service:
    compose_project => $compose_project,
    docker_image    => $docker_image,
    manage_image    => true,
    runner_dir      => $service_dir,
  }
}
