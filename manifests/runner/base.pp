# @summary A short summary of the purpose of this class
#
# Base settings for all runners
#
# @example
#   include gitlabinstall::runner::base
class gitlabinstall::runner::base (
  Stdlib::Unixpath
          $service_dir = $gitlabinstall::runner::params::service_dir,
) inherits gitlabinstall::runner::params {
  file { $service_dir:
    ensure => directory,
  }

  package { 'toml':
    ensure   => 'installed',
    provider => 'puppet_gem',
  }
}
