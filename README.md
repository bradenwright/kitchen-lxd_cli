# <a name="title"></a> Kitchen::LxdCli

A Test Kitchen Driver for LxdCli.

## <a name="overview"></a> Overview

This is a test-kitchen driver for lxd, which controls lxc.  I named it LxdCli because this is my first plugin and I wanted to leave LXD driver name in case a more extensive project is put together.

Basics are working.  I'm running lxd --version 0.20 on ubuntu 15.10.

I started the project because I really like the idea of developing containers, but kitchen-lxc wouldn't work with my version.  I also tried docker but preferred how lxd is closer to a hypervisor virtual machine.  For instance kitchen-docker my recipes that had worked on virtual machies for mongodb, the service would not start when using docker.  Ultimately I was interested in LXD and there wasn't anything out there.  I was quickly able to get my mongodb recipe working.  I figured I'd clean things up, and some features and publish it.  At least if someone like me wants to play with lxd, chef, test-kitchen they can test some basics without having to recreate the wheel.

I AM VERY OPEN TO SUGGESTIONS/HELP.  As I mentioned I haven't written a kitchen driver or published any ruby gems before so I was hesitant to even release it.

```yaml
---
driver:
  name: lxd_cli
#  public_key_path: "~/.ssh/id_rsa.pub"

provisioner:
  name: chef_zero
#  name: nodes

platforms:
# Following 3 will all use the same image (LTS), but it will be named accordingly
- name: ubuntu-14.04
- name: ubuntu-1404
- name: ubuntu-trusty
# Following 3 will all use the same image (Latest Release as of now), but it will be named accordingly
- name: ubuntu-15.10
- name: ubuntu-1510
- name: ubuntu-wily
```

As of now if you install lxd, and have a public key setup in ~/.ssh/ then you should be able to use plugin without manual intervention.  I have only tested with ubuntu container.  What does it do:

Kitchen Create

1) Creates image if its missing.  If a platform is specified LXD will check if an image with the same name exists, if not it will parse the platform name, and install the appropriate image.  If the image exists it will use that image.

2) If container does not exists, creates container.  Using the instance name as the container name, and using the image from previous step.

3) If container exists, starts it

4) copies public key from ~/.ssh/ to container /root/.ssh/


Note: if you have troubles with the public key, you can always manually setup public key on container, and publish it to an image.  If the image already exists it will not be download via test-kitchen.

Kitchen Destroy

1) Stops container if its running

2) Destroys container if it exists

LXD Links:

[LXD Basics](https://insights.ubuntu.com/2015/03/20/installing-lxd-and-the-command-line-tool/)

[LXD Publish Image](https://insights.ubuntu.com/2015/06/30/publishing-lxd-images/)

## <a name="installation"></a> Installation and Setup

Must have LXD installed on OS, I've only tested on Ubuntu 15.10

Install on command line:

gem install kitchen-lxd_cli

or use bundler:

gem "kitchen-lxd_cli"

gem "kitchen-lxd_cli", :github => "bradenwright/kitchen-lxd_cli"

gem "kitchen-lxd_cli", :path => "~/kitchen-lxd_cli"

Please read the [Driver usage][driver_usage] page for more details.

## <a name="config"></a> Configuration

public_key_path config can be manual set or is derived by default based 
~/.ssh/ directory, specifically the setting is derived by searching for:
- `~/.ssh/id_rsa.pub`
- `~/.ssh/id_dsa.pub`
- `~/.ssh/identity.pub`
- `~/.ssh/id_ecdsa.pub`

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
* Config option for adding/using lxc remote command
* Config option to publish container on verify
* Config options for static ip, cpu, mem
* Config option to install upstart (not used by default in containers)
* Config option for proxy/cache

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
