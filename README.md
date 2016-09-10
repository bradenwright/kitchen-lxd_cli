# <a name="title"></a> Kitchen::LxdCli

A Test Kitchen Driver for LXD / LXC

## <a name="overview"></a> Overview

This is a test-kitchen driver for lxd, which controls lxc.  I named it LxdCli because this is my first plugin and I wanted to leave LXD driver name in case a more extensive project is put together.  Although I've since added a lot more features than I originally planned.

I'm running lxd --version 2.0.2 on ubuntu 16.04.  Image setup, Networking options, etc will not work prior to 2.0.0 [Github Issue](https://github.com/lxc/lxd/issues/1259), use kitchen_lxd_cli 0.x.x for lxd 0.x.  Only tested with ubuntu containers, pull requests are welcome.

I started the project because I really like the idea of developing containers, but kitchen-lxc wouldn't work with my version.  I also tried docker but preferred how lxd is closer to a hypervisor virtual machine.  For instance kitchen-docker my recipes that had worked on virtual machies for mongodb, the service would not start when using docker.  I was able to get the service to start but liked the concept of system containers more than application containers.  Ultimately I was interested in LXD and there wasn't anything out there.  I was quickly able to get my mongodb recipe working.  I figured I'd clean things up, and some features and publish it.  Since then I've added numerous features, mainly with a focus on speeding up development of cookbooks, and exploring LXD.

I AM VERY OPEN TO SUGGESTIONS / HELP.  As I mentioned this is my first kitchen driver / published ruby gem.

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

Recommended for Faster Development
```yaml
---
driver:
  name: lxd_cli
  image_name: my-ubuntu-image #Publish your own image, with base install.  Including Chef.
  verifier_path: "/opt/verifier"
  lxd_proxy_install: true

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
  config:
    limits.memory: 2GB
    limits.cpu: 2
    boot.autostart: true
  domain_name: lxc
  ip_gateway: 10.0.3.1
  dns_servers: ["10.0.3.1", "8.8.8.8", "8.8.4.4"]
#  never_destroy: true
  lxd_proxy_install: true
#  lxd_proxy_destroy: true
#  lxd_proxy_verify: true
#  lxd_proxy_update: true
#  lxd_proxy_path: "~/.lxd_proxy"
#  lxd_proxy_github_url: "-b development --single-branch https://github.com/bradenwright/cookbook-lxd_polipo
  mount:
    rails_mongodb_app:
      local_path: "/mylocalpath"
      container_path: "/mnt/rails_mongodb_app"
  domain_name: localdomain
  dns_servers: ["8.8.8.8","8.8.4.4"]
  ipv4: 10.0.3.99/24
  ip_gateway: 10.0.3.1
  verifier_path: "/opt/verifier"
  publish_image_name: "kitchen-base-ubuntu-1404"
  use_publish_image: true
  publish_image_before_destroy: true
  publish_image_overwrite: true
  lxd_unique_name: true
  enable_wait_for_ssh_login: false
  username: kitchen-user



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
*  never_destroy
*  verifier_path
*  publish_image_before_destroy
*  publish_image_name
*  publish_image_overwrite
*  use_publish_image
*  lxd_proxy_install
*  lxd_proxy_destroy
*  lxd_proxy_verify
*  lxd_proxy_update
*  lxd_proxy_path
*  lxd_proxy_github_url
*  lxd_unique_name

### public_key_path

can be manual set otherwise is derived by default based 
~/.ssh/ directory, specifically the setting is derived by searching for:
- `~/.ssh/id_rsa.pub`
- `~/.ssh/id_dsa.pub`
- `~/.ssh/identity.pub`
- `~/.ssh/id_ecdsa.pub`

The public key at this location is copied to /root/.ssh in the lxc container to allow password less login.

`public_key_path: "/path/to/my/public/key"`

### image_name

Defaults to platform.name.  Also note that if the image exists it will be used and will not be created.  This allows a container to be published (image manually created).

`image_name: "my-container-image"`

### image_os

By default platform.name is split on "-" and the first element is used.  E.G. platform.name = ubuntu-14.04 then image_os = ubuntu

`image_os: "ubuntu"`

### image_release

By default platform.name is split on "-" and the second element is used.  E.G. platform.name = ubuntu-14.04 the image_release = 14.04  For ubuntu 14.04 is changed to release name, E.G. trusty, when image is being downloaded.  For Ubuntu trusty, 14.04, 1404 will all result in the same image being used, it will just be named different depending.  It may work for OS's other than ubuntu but have not tested

`image_release: "trusty"`

### profile

Default is Nil.  See LXC documentation but a lxc profile can be specified.  Which will be passed to "lxc init" command.  A String or an Array are accepted.

`profile: "migratable"`

`profile: [ "default", "migratable" ]`


### config

Default is Nil.  See LXC documentation but a lxc config container key/value can be specified.  [LXC Container Config Options](https://github.com/lxc/lxd/blob/master/specs/configuration.md#keyvalue-configuration-1).  Config options are passed to "lxc init" command.  A String or a Hash of key/value pairs is accepted.

`config: "limits.memory=2GB"`

```yaml
config:
  limits.memory: 1GB
  limits.cpu: 2
  boot.autostart: true
```

### mount
  Default is Nil.  Mount allows for local directories to be mounted inside the container.  Must have the following format:

```yaml
mount:
  myhome:
    local_path: "<%= ENV['HOME'] %>"
    container_path: "/mnt/myhome"
  mymount2:
    local_path: "/my/local/path"
    container_path: "/my/container/path"
    # Attempts to create the local_path if it doesn't exist yet
    create_source: true
```

You can mount however many directories you like.  The kitchen-lxd_cli driver will run `lxc config device add <container> <name> disk <local_path>=<container_path>` 

### domain_name

Default is nil.  String can be provided

`domain_name: "mydomain.com"`

### dns_server

Default is nil.  Which is used for dhcp, if a static ip is setup then dns servers need to be configured for chef to work.  If a static ip is supplied and no dns_server is specified it will try to use the default gateway, google dns (e.g. 10.0.3.1, 8.8.8.8, 8.8.4.4).  If a default gateway is not specified or can't be located then only google dns (8.8.8.8, 8.8.4.4) will be used.  A hash of dns_servers may be specified instead.

`dns_servers: ["10.0.3.1", "8.8.8.8", "8.8.4.4"]`

##### LXC NETWORKING OPTIONS 

LXC by default uses 10.0.3.2/24 with a gateway of 10.0.3.1.  You may use any ip space you wish, but LXD/LXC install sets up an ethernet bridge on 10.0.3.0/24 so make sure whatever network you choose to use is configured and accessible.  In Ubuntu 15.10, LXD/LXC 0.20 configuration for networking is located at /etc/default/lxc-net, another option other than static ips is to setup dhcp host/ip mappings to reserve ips (described in /etc/default/lxc-net file comments) but it didn't seem to be working for me.  You can also configure DHCP scope, etc.  I've been using static ips from 10.0.3.0/24 and those ips have worked without needing to make changes to LXD/LXC configuration, although I did change the DHCP scope to allow space for static ip addresses (just to make sure there wasn't accidentally overlap)

**NOTE:  Networking options will not work LXD 0.21, 0.22 [Github Issue](https://github.com/lxc/lxd/issues/1259)**

### ipv4

Allows for Static IP/CIDR to be set, currently netmask is not supported.  E.g. 10.0.3.100/24

`ipv4: "10.0.3.99/24"`

### ip_gateway

Allows for a default gateway to be set.  If ipv4 is used ip_gateway default value is 10.0.3.1, if dhcp is used then default gateway is given via dhcp.  Default gateway is also used as a dns_server if static ips are used and no dns server is specified.

`ip_gateway: "10.0.3.1"`

### never_destroy

Default is false.  Can be useful sometimes to keep machines intact.  It allows kitchen destroy to stop container, kitchen create can be issued to start boxes if they are not running.

`never_destroy: true`

### verifier_path

Default is nil.  If nil, then normal setting are used, i.e. /tmp/verifier is the path.  Since its in /tmp, it gets deleted on restart.  I tried other options that I've found (BUT DIDN'T WORK), like:

```
# DID NOT WORK!!!
busser:
  root_path: /opt/verifier
```

Since that option isn't working set verifier_path will create a directory if its missing and create a symbolic link from /tmp/verifier to the directroy specified.  This is particular usefuly when publishing an image.  E.g.

`verifier_path: "/opt/verifier"`

This will save verifier gems to a permanent location, I publish a base install with verifier gems install in /opt/verifier.  By publishing and using this image, everytime the container is created it doesn't have to go through the process of installing multiple gems (which can be a little slow, especially if you have to recreate boxes often).

### publish_image_before_destroy

Default is false.  If true, then after the container is stopped but before it is destroyed the container will be published as a local image.

`publish_image_before_destroy: true`

### publish_image_name

Default is "kitchen-#{instance.name}", sets the name/alias for the lxc image

`publish_image_name: "my-published-image"`

### publish_image_overwrite

Default is false.  If true if an image of the same name exists, it will be deleted so the new image of the same name can be published.

`publish_image_overwrite: true`

### use_publish_image

Default is false.  If true then if the published_image_name exists as an lxc image it will be used to instead of using image name, or the image_name which is generated based on the instance.name

`use_publish_image: true`

### lxd_proxy_install

Default is false.  If true it installs polipo proxy by cloning  into .lxd_proxy and running test kitchen in that directory.  It only runs the first time unless you tell it to update.  Also if the proxy already exists from another project, the existing container (named proxy-ubuntu-1404) will be used, started if necessary.  Recommended use for testing would be to set this value to true and leave all others as defaults.  It will significantly increase your test kitchen runs.  

`lxd_proxy_install: true`

But be sure to setup nodes in .kitchen.yml with normal proxy settings, so the proxy is used

```yaml
provisioner:
  name: chef_zero
  http_proxy: http://10.0.3.5:8123
  https_proxy: https://10.0.3.5:8123
  chef_omnibus_url: http://www.chef.io/chef/install.sh
```

chef_omnibus_url of http is provided b/c it allows proxy to be utilized for chef install, with https (aka default) chef install is not utlizing proxy.

### lxd_proxy_destroy

Default is false.  By default proxy is not destroyed and it is set to auto boot.  This way after proxy is installed once, it should just be there and usable for all your cookbooks.

`lxd_proxy_destroy: true`

### lxd_proxy_verify

Default is false.  If false then kitchen converge command is used, which speeds up the process.  If you want to run serverspec tests to ensure polipo is up set this value to true.

`lxd_proxy_verify: true`

### lxd_proxy_update

Default is false.  Very little has been tested, and could be errors that one would manually have to deal with.  But it attempts to pull from git, update berkshelf, re-run kitchen converge.  Takes extra time but may come in useful.  At this point I would recommend just destroying and recreating the lxd_proxy if there are any issues.

`lxd_proxy_update: true`

### lxd_proxy_path

Default is `~/.lxd_proxy` Path of where github gets cloned can be changed.  That location is used so only 1 copy needs to exist on disk for all cookbook.  But most of the disk space is the lxc container thats running the polipo proxy, container is named proxy-ubuntu-1404 by default.

`lxd_proxy_path: "/my/proxy/path"`

### lxd_proxy_github_url

Default is https://github.com/bradenwright/cookbook-lxd_polipo basically if can be overridden so that whatever repo is used.  Idea being that someone can customize the polipo install I have setup.  Or try to use a completely different type of proxy (not polipo) as long as the git-repo would create a proxy by running `bundle install` and `bundle exec kitchen converge`.  Also if you don't want to use github if you setup a container named proxy-ubuntu-1404, ie `lxc info proxy-ubuntu-1404` returns a box it will be used.

```yaml
lxd_proxy_github_url: "-b development --single-branch https://github.com/bradenwright/cookbook-lxd_polipo"
```

### lxd_unique_name

Default is true.  If true a file is written to .kitchen/<instance_name>.lxd with the unique name.  This file is used to identify the lxd instance.  If you don't want this feature, set to false

### enable_wait_for_ssh_login

Default is false.  If set to true container will loop until it can login to ssh, this ensures that ssh is ready before kitchen moves on to converging.  It's false by default b/c it slows things down, and I only seemed to need it after using publishing option.  Specifically if I didn't remove /root/.ssh, if I did remove /root/.ssh before publishing, then the sleep/time to setup ssh_public_key seemed to wait long enough that kitchen converge was not timing out.

`enable_wait_for_ssh_login: true`

NOTE: Hope is that I can resolve the issues of needing to wait by writing a transport that uses lxc commands and not ssh, also will improve sped since ssh login is slow.

### username

Default is `root`. If set to another user name will create home directory and set to `${username} ALL=(ALL) NOPASSWD: ALL` on `/etc/sudoers`.

`username: kitchen-user`
 
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
* Example chef cookbook which uses this driver to setup a multi-node web application
* Allow specifying name of container
* Fix issue with installing proxy on first run and running multiple nodes with `kitchen converge -p`. Need a more thorough check to see if proxy exists, right now looking for directory.  LXC shows box as running, also may want to run a check to make sure lxc shows same ip that is setup in .kitchen.yml file.
* Ability to configure options for lxd_proxy_install, such as: ip, maybe ram, etc (currently would need to be done manually, either via lxc or via .lxd_proxy/.kitchen.yml)
* Option for dhcp proxy, find ip proxy is running on in Kitchen driver and use it, by default instead of using 10.0.3.5.
* Write a transport for lxd_cli, using ssh is a lot slower than using lxc commands
* Write ServerSpec tests.  [kitchen-openstack]() and [kitchen-ec2]() have good examples.
* Update all licensing to Apache 2.0, or something else that free, some stuff may have defaulted differently.  Also check [cookbook-lxd_polipo](https://github.com/bradenwright/cookbook-lxd_polipo)
* Ability to use snapshots, along with test-kitchen to speed up testing.  Idea being if config option is set, then on destroy a snapshot will be taken.  When kitchen create is run snapshot would be reverted.  options: snapshot_name, snapshot_before_destroy, snapshot_revert_on_create
* Copy / Migrate on Destroy

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
