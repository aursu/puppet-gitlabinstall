# Changelog

All notable changes to this project will be documented in this file.

## Release 1.0.2

**Features**

Added `repo_sslverify` parameter into class `gitlabinstall::gitlab` in  order
to override global settings for this flag

**Bugfixes**

Added dependency of registry default path on gitlab package

**Known Issues**

## Release 1.1.0

**Features**

* added IP allowlist support
  see https://docs.gitlab.com/ee/administration/monitoring/ip_whitelist.html
* added Health Check support
  see https://docs.gitlab.com/ee/user/admin_area/monitoring/health_check.html
* added Relative URL support
  see https://docs.gitlab.com/omnibus/settings/configuration.html#configuring-a-relative-url-for-gitlab

**Bugfixes**

**Known Issues**

## Release 1.1.1

**Features**

**Bugfixes**

* Added ability to setup Nginx logging directory for GitLab if Nginx core is not
under module management

**Known Issues**

## Release 1.1.2

**Features**

* Added ability to export certificate that GitLab uses to sign the tokens

**Bugfixes**

**Known Issues**

## Release 1.1.3

**Features**

* Revised/reworked auth configuration

**Bugfixes**

**Known Issues**

## Release 1.1.4

**Features**

* Added ability to separate GitLab hostname and server name

**Bugfixes**

**Known Issues**

## Release 1.1.5

**Features**

* Return registry `internal_key` management back into gitlabinstall

**Bugfixes**

**Known Issues**

## Release 1.2.0

**Features**

* Added ability to setup LDAP settings

**Bugfixes**

**Known Issues**

## Release 1.2.1

**Features**

* Added additional LDAP settings

**Bugfixes**

**Known Issues**

## Release 1.3.0

**Features**

* Added authentication tokens
* Separated settinngs for external registry

**Bugfixes**

**Known Issues**

## Release 1.4.0

**Features**

* Added `access` and `ttl` properties into access token type

**Bugfixes**

**Known Issues**

## Release 1.5.0

**Features**

* Added postgresql tools setup
* Added template for tokens' map

**Bugfixes**

* Corrected name parameter for access field (not to start from slash /)
* Updated token validation (threshold should be less than ttl) if expire time
  is too close
* Changed dependency type for service cleanup
* Updated module dependencies

**Known Issues**

## Release 1.5.1

**Features**

**Bugfixes**

* Corrected nginx::resource::config resource
* Enable map directory management in case if token auth enabled

**Known Issues**

## Release 1.6.0

**Features**

* Added SMTP settings

**Bugfixes**

**Known Issues**

## Release 1.7.0

**Features**

**Bugfixes**

* set Gitlab['gitlab_workhorse']['listen_addr'] to avoid default socket location
  change to /var/opt/gitlab/gitlab-workhorse/sockets/socket

**Known Issues**

## Release 1.7.1

**Features**

**Bugfixes**

* Added dockerinstall into gitlabinstall::external_registry to avoid dependency errors

**Known Issues**

## Release 1.7.2

**Features**

**Bugfixes**

* Updated puppet/gitlab version depenndency

**Known Issues**

## Release 1.7.3

**Features**

**Bugfixes**

* Added `restorecon` command for workhorse socket to fix error
  [crit] 26914#26914: *1 connect() to unix:/var/opt/gitlab/gitlab-workhorse/socket failed (13: Permission denied) while connecting to upstream
* Added `gitlab-rake db:migrate` command to fix error described in
  https://forum.gitlab.com/t/upgrading-from-13-9-4-to-13-10-0-results-in-an-error-500/50685/2

**Known Issues**

## Release 1.8.0

**Features**

* Added GitLab Runner docker service installation
  (no Runner registration)

**Bugfixes**

**Known Issues**

## Release 1.8.1

**Features**

* Bugfix: decline empty array for runners service extra hosts

**Bugfixes**

**Known Issues**

## Release 1.9.0

**Features**

* Added runner registration

**Bugfixes**

**Known Issues**

## Release 1.9.1

**Features**

* Moved default SSL settings into parameters

**Bugfixes**

**Known Issues**

## Release 1.9.2

**Features**

* Upgraded default GitLab version to latest one [14.0.4]

**Bugfixes**

**Known Issues**

## Release 1.9.3

**Features**

* Upgraded default GitLab version to latest one [14.2.4]
* Added database_upgrade flag

**Bugfixes**

**Known Issues**

## Release 1.9.4

**Features**

* Added backup functionality for GitLab via cron job
* Upgraded default GitLab version to latest one [14.4.1]

**Bugfixes**

**Known Issues**

## Release 1.9.5

**Features**

* Added ability to setup custom artifact path
* Upgraded default GitLab version to latest one [14.10.0]
* PDK upgrade to version 2.3.0

**Bugfixes**

**Known Issues**

## Release 1.9.6

**Features**

* Added ability to specify version for jwt gem
  because latest versions (> 2.4.0 ) depend on Ruby >= 2.5
  that is not the case for Puppet 5.5

**Bugfixes**

**Known Issues**

## Release 1.9.7

**Features**

* Added ability to setup different ID for LDAP server provider

**Bugfixes**

**Known Issues**

## Release 1.9.8

**Features**

* Added Git data path into module parameters
* Upgraded default GitLab version to latest one [15.3.3]

**Bugfixes**

**Known Issues**

## Release 1.9.9

**Features**

* Upgraded default GitLab version to latest one [15.10.2]
* Upgraded default GitLab runner version to latest one [15.10.1]

**Bugfixes**

**Known Issues**

## Release 1.9.10

**Features**

**Bugfixes**

* Added auth_type => 'gitlab_or_ldap' into registry token data

**Known Issues**