# @summary GitLab runner parameters
#
# GitLab runner parameters
#
# @example
#   include gitlabinstall::runner::params
class gitlabinstall::runner::params {
  $compose_project = 'gitlab'
  $compose_service = 'runner'
  $compose_service_title = "${compose_project}/${compose_service}"

  $service_dir = '/srv/gitlab-runner'
  $persistent_dir = "${service_dir}/config"
}
