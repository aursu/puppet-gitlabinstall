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