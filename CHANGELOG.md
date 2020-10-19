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