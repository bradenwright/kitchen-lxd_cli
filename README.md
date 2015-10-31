# <a name="title"></a> Kitchen::LxdCli

A Test Kitchen Driver for LxdCli.

At this point would NOT recommend using in Production.

## <a name="overview"></a> Overview

This is a test-kitchen driver for lxd, which controls lxc.  I named it LxdCli because this is my first plugin and I wanted to leave LXD driver name in case a more extensive project is put together.

Basics are working.  I'm running lxd --version 0.20 on ubuntu 15.10.

I started the project because I really like the idea of developing containers, but kitchen-lxc wouldn't work with my version.  I also tried docker but preferred how lxd is closer to a hypervisor virtual machine.  For instance kitchen-docker my recipes that had worked on virtual machies for mongodb, the service would not start when using docker.  Ultimately I was interested in LXD and there wasn't anything out there.  I was quickly able to get my mongodb recipe working.  I figured I'd clean things up, and some features and publish it.  At least if someone like me wants to play with lxd, chef, test-kitchen they can test some basics without having to recreate the wheel.

I AM VERY OPEN TO SUGGESTIONS/HELP.  As I mentioned I haven't written a kitchen driver or published any ruby gems before so I was hesitant to even release it.

Minimal .kitchen.yml
```yaml
---
driver:
  name: lxd_cli

provisioner:
  name: chef_zero

platforms:
- name: ubuntu-14.04

suites:
- name: default
  run_list:
  attributes:
```

All Options Shown .kitchen.yml
```yaml
---
driver:
  name: lxd_cli
  public_key_path: "/my/path/id_rsa.pub"
  image_name: my-ubuntu-image
  image_os: ubuntu
  image_release: trusty
  profile: my_lxc_profile
  config: limits.memory=2G
  domain_name: localdomain
  dns_servers: ["8.8.8.8","8.8.4.4"]
  ipv4: 10.0.3.99/24
  ip_gateway: 10.0.3.1
  stop_instead_of_destroy: true

provisioner:
  name: chef_zero

platforms:
# Following 3 will all use the same image (LTS), but it will be named accordingly
- name: ubuntu-14.04
- name: ubuntu-1404
- name: ubuntu-trusty
# Following 3 will all use the same image (Latest Release as of now), but it will be named accordingly
- name: ubuntu-15.10
- name: ubuntu-1510
- name: ubuntu-wily

suites:
- name: web
  driver_config:
    ipv4: 10.0.3.31/24
  run_list:
- name: db
  driver_config:
    ipv4: 10.0.3.32/24
  run_list:

```

As of now if you install lxd, and have a public key setup in ~/.ssh/ then you should be able to use plugin without manual intervention.  I have only tested with Ubuntu containers.  Good chance most things will work in other Platforms, but some networking config is Ubuntu/Debian specific (dns_servers, domain_name).

LXD Links:

[LXD Basics](https://insights.ubuntu.com/2015/03/20/installing-lxd-and-the-command-line-tool/)

[LXD Publish Image](https://insights.ubuntu.com/2015/06/30/publishing-lxd-images/)

## <a name="installation"></a> Installation and Setup

Must have LXD installed on OS, I've only tested on Ubuntu 15.10

Install on command line:
```
gem install kitchen-lxd_cli
```
or use bundler:
```
gem "kitchen-lxd_cli"

gem "kitchen-lxd_cli", :github => "bradenwright/kitchen-lxd_cli"

gem "kitchen-lxd_cli", :path => "~/kitchen-lxd_cli"
```
Please read the [Driver usage][driver_usage] page for more details.

## <a name="config"></a> Configuration

Current config options:

*  image_name
*  image_os
*  image_release
*  profile
*  config
*  domain_name
*  dns_servers
*  ipv4
*  ip_gateway
*  stop_instead_of_destroy

public_key_path: /my/path/public_key_file

can be manual set otherwise is derived by default based 
~/.ssh/ directory, specifically the setting is derived by searching for:
- `~/.ssh/id_rsa.pub`
- `~/.ssh/id_dsa.pub`
- `~/.ssh/identity.pub`
- `~/.ssh/id_ecdsa.pub`

The public key at this location is copied to /root/.ssh in the lxc container to allow password less login.

image_name:

Defaults to platform.name.  Also note that if the image exists it will be used and will not be created.  This allows a container to be published (image manually created).

image_os:

By default platform.name is split on "-" and the first element is used.  E.G. platform.name = ubuntu-14.04 then image_os = ubuntu

image_release:

By default platform.name is split on "-" and the second element is used.  E.G. platform.name = ubuntu-14.04 the image_release = 14.04  For ubuntu 14.04 is changed to release name, E.G. trusty, when image is being downloaded.  For Ubuntu trusty, 14.04, 1404 will all result in the same image being used, it will just be named different depending.  It may work for OS's other than ubuntu but have not tested

profile:

Default is Nil.  See LXC documentation but a lxc profile can be specified.  Which will be passed to "lxc init" command

config:

Default is Nil.  See LXC documentation but a lxc config container key/value can be specified.  [LXC Container Config Options](https://github.com/lxc/lxd/blob/master/specs/configuration.md#keyvalue-configuration-1).  Again option is passed to "lxc init" command.  NOTE: I haven't successfully set more than 1 config option via "lxc init" command, so still need to figure that out, or rewrite this piece.

domain_name:

Default is nil.

dns_server:

Default is nil.  Which is used for dhcp, if a static ip is setup then dns servers need to be configured for chef to work.  If a static ip is supplied and no dns_server is specified it will try to use the default gateway, google dns (e.g. 10.0.3.1, 8.8.8.8, 8.8.4.4).  If a default gateway is not specified or can't be located then only google dns (8.8.8.8, 8.8.4.4) will be used.  A hash of dns_servers may be specified instead.

LXC NETWORKING OPTIONS: LXC by default uses 10.0.3.2/24 with a gateway of 10.0.3.1.  You may use any ip space you wish, but LXD/LXC install sets up an ethernet bridge on 10.0.3.0/24 so make sure whatever network you choose to use is configured and accessible.  In Ubuntu 15.10, LXD/LXC 0.20 configuration for networking is located at /etc/default/lxc-net, another option other than static ips is to setup dhcp host/ip mappings to reserve ips (described in /etc/default/lxc-net file comments) but it didn't seem to be working for me.  You can also configure DHCP scope, etc.  I've been using static ips from 10.0.3.0/24 and those ips have worked without needing to make changes to LXD/LXC configuration, although I did change the DHCP scope to allow space for static ip addresses (just to make sure there wasn't accidentally overlap)

ipv4:

Allows for Static IP/CIDR to be set, currently netmask is not supported.  E.g. 10.0.3.100/24

ip_gateway:

Allows for a default gateway to be set.  If ipv4 is used ip_gateway default value is 10.0.3.1, if dhcp is used then default gateway is given via dhcp.  Default gateway is also used as a dns_server if static ips are used and no dns server is specified.


stop_instead_of_destroy:

Default is false.  Can be useful sometimes to keep machines intact.  It allows kitchen destroy to stop container, kitchen create can be issued to start boxes if they are not running.

### <a name="config-require-chef-omnibus"></a> require\_chef\_omnibus

Determines whether or not a Chef [Omnibus package][chef_omnibus_dl] will be
installed. There are several different behaviors available:

* `true` - the latest release will be installed. Subsequent converges
  will skip re-installing if chef is present.
* `latest` - the latest release will be installed. Subsequent converges
  will always re-install even if chef is present.
* `<VERSION_STRING>` (ex: `10.24.0`) - the desired version string will
  be passed the the install.sh script. Subsequent converges will skip if
  the installed version and the desired version match.
* `false` or `nil` - no chef is installed.

The default value is unset, or `nil`.

## <a name="roadmap"></a> Roadmap 
* Update/Clean README 
* Config option for remote host, remote user, etc.  So lxc can be launched on a remote server, not just locally
* Config option to add remote for lxc, so images can be downloaded from other locations.  Currently would have to manually be done in LXD/LXC
* Config option to publish container on verify
* Config option to install upstart (not used by default in containers)
* Config option for proxy/cache
* Ability to set more than 1 config (key/value)
* Example chef cookbook which uses this driver to setup a multi-node web application

## <a name="development"></a> Development

* Source hosted at [GitHub][repo]
* Report issues/questions/feature requests on [GitHub Issues][issues]

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## <a name="authors"></a> Authors

Created and maintained by [Braden Wright][author] (<braden.m.wright@gmail.com>)

## <a name="license"></a> License

Apache 2.0 (see [LICENSE][license])


[author]:           https://github.com/bradenwright
[issues]:           https://github.com/bradenwright/kitchen-lxd_cli/issues
[license]:          https://github.com/bradenwright/kitchen-lxd_cli/blob/master/LICENSE
[repo]:             https://github.com/bradenwright/kitchen-lxd_cli
[driver_usage]:     http://docs.kitchen-ci.org/drivers/usage
[chef_omnibus_dl]:  http://www.getchef.com/chef/install/
