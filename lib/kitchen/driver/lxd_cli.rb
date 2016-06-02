# -*- encoding: utf-8 -*-
#
# Author:: Braden Wright (<braden.m.wright@gmail.com>)
#
# Copyright (C) 2015, Braden Wright
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://wwoow.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen'

module Kitchen

  module Driver

    # LxdCli driver for Kitchen.
    #
    # @author Braden Wright <braden.m.wright@gmail.com>
    class LxdCli < Kitchen::Driver::Base
      kitchen_driver_api_version 2

      default_config :public_key_path do
        [
          File.expand_path('~/.ssh/id_rsa.pub'),
          File.expand_path('~/.ssh/id_dsa.pub'),
          File.expand_path('~/.ssh/identity.pub'),
          File.expand_path('~/.ssh/id_ecdsa.pub')
        ].find { |path| File.exist?(path) }
      end
      default_config :never_destroy, false
      default_config :lxd_proxy_path, "#{ENV['HOME']}/.lxd_proxy"
      default_config :lxd_proxy_update, false
      default_config :username, "root"

      required_config :public_key_path

      def create(state)
        install_proxy if config[:lxd_proxy_install] && config[:lxd_proxy_install] == true

        unless exists?
          image_name = create_image_if_missing
          profile_args = setup_profile_args if config[:profile]
          config_args = setup_config_args if config[:config]
          info("Initializing container #{instance.name}")
          run_lxc_command("init #{image_name} #{instance.name} #{profile_args} #{config_args}")
        end

        config_and_start_container unless running?
        configure_dns
        lxc_ip = wait_for_ip_address
        state[:hostname] = lxc_ip
        state[:username] = config[:username]
        setup_ssh_access
        wait_for_ssh_login(lxc_ip) if config[:enable_wait_for_ssh_login] == "true"
        IO.popen("lxc exec #{instance.name} bash", "r+") do |p|
          p.puts("if [ ! -d '#{config[:verifier_path]}' ]; then mkdir -p #{config[:verifier_path]}; fi") 
          p.puts("if [ ! -L '/tmp/verifier' ]; then ln -s #{config[:verifier_path]} /tmp/verifier; fi")
        end if config[:verifier_path] && config[:verifier_path].length > 0
      end

      def destroy(state)
        if exists?
          if running?
            info("Stopping container #{instance.name}")
            run_lxc_command("stop #{instance.name}")
          end

          publish_image if config[:publish_image_before_destroy]

          unless config[:never_destroy]
            info("Deleting container #{instance.name}")
            run_lxc_command("delete #{instance.name}") unless config[:never_destroy] && config[:never_destroy] == true
          end
        end
        state.delete(:hostname)
        destroy_proxy if config[:lxd_proxy_destroy] && config[:lxd_proxy_destroy] == true
      end

      private
        def exists?
          `lxc info #{instance.name} > /dev/null 2>&1`
          if $?.to_i == 0
            debug("Container #{instance.name} exists")
            return true
          else
            debug("Container #{instance.name} doesn't exist")
            return false
          end
        end

        def running?
          status = `lxc info #{instance.name}`.match(/Status: ([a-zA-Z]+)[\n]/).captures[0].upcase
          if status == "RUNNING"
            debug("Container #{instance.name} is running")
            return true
          else
            debug("Container #{instance.name} isn't running")
            return false
          end
        end

        def create_image_if_missing
          image_name = get_image_name

          unless image_exists?(image_name)
            info("Creating image #{image_name} now.")
            image = get_image_info
            image_os = config[:image_os] 
            image_os ||= image[:os]
            image_release = config[:image_release] 
            image_release ||= image[:release]
            debug("Ran command: lxd-images import #{image_os} #{image_release} --alias #{image_name}")
            IO.popen("lxd-images import #{image_os} #{image_release} --alias #{image_name}", "w") { |pipe| puts pipe.gets rescue nil }
          end

          return image_name
        end

        def get_image_info
          platform, release = instance.platform.name.split('-')
          if platform.downcase == "ubuntu"
            case release.downcase
            when "14.04", "1404", "trusty", "", nil
              image = { :os => platform, :release => "trusty" }
            when "14.10", "1410", "utopic"
              image = { :os => platform, :release => "utopic" }
            when "15.04", "1504", "vivid"
              image = { :os => platform, :release => "vivid" }
            when "15.10", "1510", "wily"
              image = { :os => platform, :release => "wily" }
            when "16.04", "1604", "xenial"
              image = { :os => platform, :release => "xenial" }
            else
              image = { :os => platform, :release => release }
            end
          else
            image = { :os => platform, :release => release }
          end
          return image
        end

        def publish_image
          publish_image_name = get_publish_image_name
          if image_exists?(publish_image_name)
            if config[:publish_image_overwrite] == true
              info("Deleting existing image #{publish_image_name}, so image of same name can be published")
              run_lxc_command("image delete #{publish_image_name}")
            else
              raise "Image #{publish_image_name} already exists!  If you wish to overwrite it set publish_image_overwrite: true in kitchen.yml"
            end
          end
          info("Publishing image #{publish_image_name}")
          run_lxc_command("publish #{instance.name} --alias #{publish_image_name}")
        end

        def get_image_name
          image_name = get_publish_image_name
          unless config[:use_publish_image] == true && image_exists?(image_name)
            image_name = config[:image_name] 
            image_name ||= instance.platform.name
          end

          debug("Image Name is #{image_name}")
          return image_name
        end

        def get_publish_image_name
          publish_image_name = config[:publish_image_name]
          publish_image_name ||= "kitchen-#{instance.name}"

          debug("Publish Image Name is #{publish_image_name}")
          return publish_image_name
        end

        def image_exists?(image_name)
          `lxc image show #{image_name} > /dev/null 2>&1`
          if $?.to_i == 0
            debug("Image #{image_name} exists")
            return true
          else
            debug("Image #{image_name} does not exist")
            return false
          end
        end

        def config_and_start_container
          config[:ip_gateway] ||= "auto"
          arg_disable_dhcp = ""

          if config[:ipv4]
            IO.popen("bash", "r+") do |p|
              p.puts("echo -e \"lxc.network.type = veth\nlxc.network.name = eth0\nlxc.network.link = lxcbr0\nlxc.network.ipv4 = #{config[:ipv4]}\nlxc.network.ipv4.gateway = #{config[:ip_gateway]}\nlxc.network.flags = up\" | lxc config set #{instance.name} raw.lxc -")
              p.puts("exit")
            end
            arg_disable_dhcp = "&& lxc exec #{instance.name} -- sed -i 's/dhcp/manual/g' /etc/network/interfaces.d/eth0.cfg"
          end

          info("Starting container #{instance.name}")
          run_lxc_command("start #{instance.name} #{arg_disable_dhcp}")
          setup_mount_bindings if config[:mount].class == Hash
        end

        def setup_config_args
          config_args = ""
          if config[:config].class == String
            config_args += " -c #{config[:config]}"
          else
            config[:config].each do |key, value|
              config_args += " -c #{key}=#{value}"
            end
          end
          if config[:mount].class == Hash
            debug("security.privileged=true is added to Config Args, b/c its needed for mount binding")
            config_args += " -c security.privileged=true"
          end
          debug("Config Args: #{config_args}")
          return config_args
        end

        def setup_profile_args
          profile_args = ""
          if config[:profile].class == String
            profile_args += " -p #{config[:profile]}"
          else
            config[:profile].each do |profile|
              profile_args += " -p #{profile}"
            end
          end
          debug("Profile Args: #{profile_args}")
          return profile_args
        end

        def setup_mount_bindings
          config[:mount].each do |mount_name, mount_binding|
            if mount_name && mount_binding[:local_path] && mount_binding[:container_path]
              run_lxc_command("config device add #{instance.name} #{mount_name} disk source=#{mount_binding[:local_path]} path=#{mount_binding[:container_path]}")
            end
          end if config[:mount].class == Hash
        end

        def configure_dns
          IO.popen("lxc exec #{instance.name} bash", "r+") do |p|
            dns_servers = ""
            config[:dns_servers].each do |dns_server|
              dns_servers += "nameserver #{dns_server}\n"
            end if config[:dns_servers]

            case config[:ip_gateway]
            when "auto", ""
              dns_servers = "nameserver 8.8.8.8\nnameserver 8.8.4.4"
              dns_servers = "nameserver 8.8.8.8\nnameserver 8.8.4.4"
            else
              dns_servers = "nameserver #{config[:ip_gateway]}\nnameserver 8.8.8.8\nnameserver 8.8.4.4"
            end if config[:ipv4] && dns_servers.length == 0

            if dns_servers.length > 0
              wait_for_path("/etc/resolvconf/resolv.conf.d/base")
              debug("Setting up the following dns servers via /etc/resolvconf/resolv.conf.d/base:")
              debug(dns_servers.gsub("\n", ' '))
              p.puts(" echo \"#{dns_servers.chomp}\" > /etc/resolvconf/resolv.conf.d/base")
              wait_for_path("/run/resolvconf/interface")
              p.puts("resolvconf -u")
            end

            debug("Setting up /etc/hosts")
            if config[:domain_name]
#              p.puts("echo -e \"  dns-search #{config[:domain_name]}\" >> /etc/network/interfaces.d/eth0.cfg")
              args_host = "#{instance.name}.#{config[:domain_name]} #{instance.name}"
            end
            args_host ||= "#{instance.name}"
            wait_for_path("/etc/hosts")
            p.puts("if grep -iq '127.0.1.1' /etc/hosts; then")
            p.puts("sed -i 's/^127.0.1.1.*$/127.0.1.1\t#{args_host}/' /etc/hosts")
            p.puts("else echo '#***** Setup by Kitchen-LxdCli driver *****#' >> /etc/hosts")
            p.puts("echo -e '127.0.1.1\t#{args_host}' >> /etc/hosts; fi")
            p.puts("exit")
          end
        end

        def setup_ssh_access
          info("Setting up public key #{config[:public_key_path]} on #{instance.name}")
          unless config[:username] == "root"
             create_ssh_user
             info("Checking /home/#{config[:username]}/.ssh on #{instance.name}")
             wait_for_path("/home/#{config[:username]}/.ssh")
          else
             info("Check /#{config[:username]}/.ssh on #{instance.name}")
             wait_for_path("/#{config[:username]}/.ssh")
          end

          begin
            debug("Uploading public key...")
            unless config[:username] == "root"
              `lxc file push #{config[:public_key_path]} #{instance.name}/home/#{config[:username]}/.ssh/authorized_keys 2> /dev/null`
            else
              `lxc file push #{config[:public_key_path]} #{instance.name}/#{config[:username]}/.ssh/authorized_keys 2> /dev/null`
            end
            break if $?.to_i == 0
            sleep 0.3
          end while true

          debug("Finished Copying public key from #{config[:public_key_path]} to #{instance.name}")
        end

        def create_ssh_user
          info("Create user #{config[:username]} on #{instance.name}")
          `lxc exec #{instance.name} -- useradd -m -G sudo #{config[:username]} -s /bin/bash`
          `lxc exec #{instance.name} -- mkdir /home/#{config[:username]}/.ssh`
          `lxc exec #{instance.name} -- chown #{config[:username]}:#{config[:username]} /home/#{config[:username]}/.ssh`
          `lxc exec #{instance.name} -- sh -c "echo '#{config[:username]} ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"`
        end

        def install_proxy
          IO.popen("bash", "w") do |p|
            if config[:lxd_proxy_verify] == true
              kitchen_command = "kitchen verify"
            else
              kitchen_command = "kitchen converge"
            end

            #TODO: more thorough check to see if proxy is running.  Check via lxc commands
            if config[:lxd_proxy_update] == true && File.exists?(config[:lxd_proxy_path])
              debug("Updating proxy, if it fails you may either not want to update or recreate proxy-ubuntu-1404")
              p.puts("cd #{config[:lxd_proxy_path]}")
              p.puts("git pull")
              p.puts("bundle update")
              p.puts("berks update")
              p.puts("bundle exec #{kitchen_command}")
            elsif !File.exists?(config[:lxd_proxy_path])
              github_url = config[:lxd_proxy_github_url] || "https://github.com/bradenwright/cookbook-lxd_polipo"
              p.puts("git clone #{github_url} #{config[:lxd_proxy_path]}")
              p.puts("cd #{config[:lxd_proxy_path]}")
              p.puts("bundle install")
              p.puts("bundle exec #{kitchen_command}")
            end
            #TODO: if Rakefile found run rake install instead
            # This would allow others to build out different options
            # for more complicated proxy installs
          end rescue nil
        end

        def destroy_proxy
          IO.popen("bash", "w") do |p|
            if File.exists?(config[:lxd_proxy_path])
              p.puts("cd #{config[:lxd_proxy_path]}")
              p.puts("bundle exec kitchen destroy")
              p.puts("cd ..")
              p.puts("rm -rf #{config[:lxd_proxy_path]}")
            end
          end
        end

        def wait_for_ip_address
          info("Waiting for network to become ready")
          begin
            lxc_info = `lxc info #{instance.name}`.match(/eth0:\tinet\t(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/)
            debug("Still waiting for IP Address...")
            lxc_ip = lxc_info.captures[0].to_s if lxc_info && lxc_info.captures
            break if lxc_ip && lxc_ip.length > 7
            sleep 0.3
          end while true
          debug("Found Ip Address #{lxc_ip}")
          return lxc_ip
        end

        def wait_for_path(path)
          begin
            debug("Waiting for #{path} to become available...")
            run_lxc_command("exec #{instance.name} -- ls #{path} > /dev/null 2>&1")
            break if $?.to_i == 0
            sleep 0.3
          end while true
          debug("Found #{path}")
        end

        def wait_for_ssh_login(ip)
          begin
            debug("Trying to login into #{ip} via SSH...")
            `ssh #{config[:username]}@#{ip} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no 'true' > /dev/null 2>&1`
            break if $?.to_i == 0
            sleep 0.3
          end while true
          debug("SSH is up, able to login at #{config[:username]}@#{ip}")
        end

        def run_lxc_command(cmd)
          run_local_command("lxc #{cmd}") if cmd
        end

        def run_local_command(cmd)
          debug("run_local_command ran: #{cmd}")
          `#{cmd}` if cmd
          debug("Command finished: #{$?.to_s}")
        end

        def debug_note_about_configuring_ip
          debug("NOTE: Restarting seemed to be the only way I could get things to work.  Tried lxc profiles, config options.  Tried restart networking service but it didn't work, also tried passing command like ifconfig 10.0.3.x/24 eth0 up.  Which set the ip but after container ran for a while, it would reset to dhcp address that had been assigned.  Restarting container seems to be working, and is really fast.  Open to better alternatives.")
        end

        
=begin
       def configure_ip_via_lxc_restart
         debug("Configuring new ip address on eth0")

         IO.popen("lxc exec #{instance.name} bash", "r+") do |p|
           p.puts('echo -e "#############################################" > /etc/network/interfaces.d/eth0.cfg')
           p.puts('echo -e "# DO NOT EDIT CONTROLLED BY KITCHEN-LXC_CLI #" >> /etc/network/interfaces.d/eth0.cfg')
           p.puts('echo -e "#############################################" >> /etc/network/interfaces.d/eth0.cfg')
           p.puts('echo -e "auto eth0" >> /etc/network/interfaces.d/eth0.cfg')
           if config[:ipv4]
             config[:ip_gateway] ||= "10.0.3.1"
             config[:dns_servers] ||= [ "8.8.8.8", "8.8.4.4" ]
             p.puts('echo -e "  iface eth0 inet static" >> /etc/network/interfaces.d/eth0.cfg')
             p.puts("echo -e \"  address #{config[:ipv4]}\" >> /etc/network/interfaces.d/eth0.cfg")
           else
             p.puts('echo -e "  iface eth0 inet dhcp" >> /etc/network/interfaces.d/eth0.cfg')
           end
           p.puts("echo -e \"  gateway #{config[:ip_gateway]}\" >> /etc/network/interfaces.d/eth0.cfg") if config[:ip_gateway]
           config[:dns_servers].each do |dns_server|
             p.puts("echo -e \"  dns-nameserver #{dns_server}\" >> /etc/network/interfaces.d/eth0.cfg")
           end if config[:dns_servers]
           if config[:domain_name]
             p.puts("echo -e \"  dns-search #{config[:domain_name]}\" >> /etc/network/interfaces.d/eth0.cfg")
           end
           p.puts("exit")
         end
         debug("Finished configuring new ip address, restarting #{instance.name} for settings to take effect")
         debug_note_about_configuring_ip
         wait_for_ip_address
         sleep 3 # Was hanging more often than not whenever I lowered the sleep
         debug("Restarting #{instance.name}")
         run_lxc_command("restart #{instance.name}")
         debug("Finished restarting #{instance.name} ip address should be configured")
       end
=end

    end
  end
end
