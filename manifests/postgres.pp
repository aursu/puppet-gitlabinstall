# @summary Install postgres database and pg_trgm extension
#
# Install postgres database and pg_trgm extension
#
# @example
#   include gitlabinstall::postgres
#
class gitlabinstall::postgres (
  String[8]
          $database_password   = $gitlabinstall::database_password,
  Boolean $manage_service      = $gitlabinstall::manage_postgresql_core,
  String  $database_username   = $gitlabinstall::params::database_username,
  String  $database_name       = $gitlabinstall::params::database_name,
  Boolean $system_tools_setup  = $gitlabinstall::pg_tools_setup,
) inherits gitlabinstall::params
{
  if $manage_service {
    include lsys::postgres
  }

  postgresql::server::db { $database_name:
    user     => $database_username,
    password => $database_password,
  }

  postgresql::server::extension { "${database_name}-pg_trgm":
    extension => 'pg_trgm',
    database  => $database_name,
    require   => Postgresql::Server::Db[$database_name],
  }

  # GitLab 13.2.0 relies on the `btree_gist` extension for PostgreSQL
  postgresql::server::extension { "${database_name}-btree_gist":
    extension => 'btree_gist',
    database  => $database_name,
    require   => Postgresql::Server::Db[$database_name],
  }

  # https://docs.gitlab.com/omnibus/settings/database.html#backup-and-restore-a-non-packaged-postgresql-database
  if $system_tools_setup {
    include postgresql::params

    $bindir = $postgresql::params::bindir
    $pg_dump_path = "${bindir}/pg_dump"
    $psql_path = "${bindir}/psql"

    file {
      default:
        ensure => link,
        before => Class['gitlab::install'],
      ;
      '/opt/gitlab/bin/pg_dump':
        target => $pg_dump_path,
      ;
      '/opt/gitlab/bin/psql':
        target => $psql_path,
      ;
    }
  }
}
