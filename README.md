# gitlabinstall

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with gitlabinstall](#setup)
    * [What gitlabinstall affects](#what-gitlabinstall-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with gitlabinstall](#beginning-with-gitlabinstall)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

This module main goal is to install GitLab and provide ability to intagrate it
with externally managed Nginx, Postgres and Docker Registry.

## Setup


### What gitlabinstall affects **OPTIONAL**

gitlabinstall installs gitlab-ce Omnibus package from https://packages.gitlab.com/gitlab/gitlab-ce.
Exact package version should be provided

Also it could manage Nginx setup (non-bundled) and Postgres setup (also non-bundled)

SSL certificates management is also included

### Setup Requirements **OPTIONAL**

It requires to use custom fork of Puppet Nginx module located on GitHub.

For .fixtures.yml

```
nginx:
  repo: https://github.com/aursu/puppet-nginx.git
  ref: tags/v2.0.1-rc0.3
```

and for Puppetfile:

```
mod 'nginx',
  :git => 'https://github.com/aursu/puppet-nginx.git',
  :tag => 'v2.0.1-rc0.3'
```

Also requires non-published on Puppet Forge module `aursu::lsys` which is set
of different basic profiles

Puppetfile setup:

```
mod 'lsys',
  :git => 'https://github.com/aursu/puppet-lsys.git',
  :tag => 'v0.5.1'
```

Also requires non-published on Puppet Forge module `aursu::dockerinstall` which is set
of different Docker related features

Puppetfile setup:

```
mod 'dockerinstall',
  :git => 'https://github.com/aursu/puppet-dockerinstall.git',
  :tag => 'v0.6.4'
```

### Beginning with gitlabinstall

Main class for GitLab installation is `gitlabinstall::gitlab`:

```
class { 'gitlabinstall':
  external_url          => 'https://gitlab.domain.tld',
}
class { 'gitlabinstall::gitlab':
  database_password     => 'secret',
  gitlab_package_ensure => '13.3.5-ce.0.el7',
}
```

## Usage

### External container registry integration

Use it with registry installed on separate host and on the same host as PuppetDB:

```
  class { 'gitlabinstall':
    external_url          => 'https://gitlab.domain.tld',
  }
  class { 'gitlabinstall::gitlab':
    cert_identity             => '*.domain.tld',
    # DevCI has PuppetDB which listen on 8080, PuppetDB could be used
    # externally but not GitLab Unicorn
    gitlab_rails_port         => 8008,
    monitoring                => false,
    external_registry_service => true,
    registry_host             => 'registry.domain.tld',
    registry_api_url          => 'http://registry.domain.tld:5000',
    gitlab_package_ensure     => '12.10.14-ce.0.el7',
  }
```

Use it with registry on the same host:

```
  class { 'gitlabinstall':
    external_url          => 'https://gitlab.domain.tld',
  }
  class { 'gitlabinstall::gitlab':
    cert_identity             => '*.domain.tld',
    external_registry_service => true,
    registry_host             => 'registry.domain.tld',
  }
```

### LDAP settings

Basic setup:

```
  class { 'gitlabinstall':
    external_url          => 'https://gitlab.domain.tld',
    ldap_enabled          => true,
    ldap_host             => 'ldap.mydomain.com',
    ldap_password         => 'secret',
    ldap_base             => 'ou=people,dc=gitlab,dc=example',
  }
  class { 'gitlabinstall::gitlab':
    cert_identity             => '*.domain.tld',
    external_registry_service => true,
    registry_host             => 'registry.domain.tld',
  }
```

With more LDAP settings:

```
  class { 'gitlabinstall':
    external_url          => 'https://gitlab.domain.tld',
  }
  class { 'gitlabinstall::ldap':
    host                  => 'ldap.mydomain.com',
    password              => 'secret',
    base                  => 'ou=people,dc=gitlab,dc=example',

    bind_dn               => 'CN=Gitlab,OU=Users,DC=domain,DC=com',
  }
  class { 'gitlabinstall::gitlab':
    cert_identity             => '*.domain.tld',
    external_registry_service => true,
    registry_host             => 'registry.domain.tld',
    ldap_enabled              => true,
  }
```

## Reference

See REFERENCE.md

## Limitations

## Development

## Release Notes/Contributors/Etc. **Optional**
