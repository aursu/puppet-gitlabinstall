# @summary Install postgres database and pg_trgm extension
#
# Install postgres database and pg_trgm extension
#
# @example
#   include gitlabinstall::postgres
#
# @param database_upgrade
#   Avoid Postgres resources management when PostgreSQL is updating
#
class gitlabinstall::postgres (
  String[8] $database_password = $gitlabinstall::database_password,
  Boolean $manage_service = $gitlabinstall::manage_postgresql_core,
  String $database_username = $gitlabinstall::params::database_username,
  String $database_name = $gitlabinstall::params::database_name,
  Boolean $system_tools_setup = $gitlabinstall::pg_tools_setup,
  Boolean $database_upgrade = $gitlabinstall::database_upgrade,
  Integer $max_connections = $gitlabinstall::params::database_max_connections,
) inherits gitlabinstall::params {
  if $manage_service {
    include lsys_postgresql

    # if not equal default value - set it
    unless $max_connections == $gitlabinstall::params::database_max_connections {
      postgresql::server::config_entry { 'max_connections':
        value => $max_connections,
      }
    }
  }

  unless $database_upgrade {
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

    postgresql::server::extension { "${database_name}-plpgsql":
      extension => 'plpgsql',
      database  => $database_name,
      require   => Postgresql::Server::Db[$database_name],
    }

    if $manage_service and versioncmp($postgresql::globals::globals_version, '15.0') >= 0 {
      postgresql::server::grant { "${database_name}:SCHEMA:public:${database_username}":
        role        => $database_username,
        db          => $database_name,
        object_name => 'public',
        privilege   => 'ALL',
        object_type => 'SCHEMA',
      }
    }
  }

  # https://docs.gitlab.com/omnibus/settings/database.html#backup-and-restore-a-non-packaged-postgresql-database
  if $system_tools_setup {
    include postgresql::params

    $bindir = $postgresql::params::bindir
    $pg_dump_path = "${bindir}/pg_dump"
    $psql_path = "${bindir}/psql"

    unless $database_upgrade {
      exec { 'mkdir -p /opt/gitlab/bin':
        creates => '/opt/gitlab/bin',
        path    => '/bin:/usr/bin',
      }

      file {
        default:
          ensure  => link,
          require => Exec['mkdir -p /opt/gitlab/bin'],
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
}
