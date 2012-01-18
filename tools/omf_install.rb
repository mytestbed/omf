#!/usr/bin/env ruby

# OMF installation script

# This installation script assumes the testbed configuration as in the OMF 
# installation guide:
# http://mytestbed.net/projects/omf/wiki/Installation_Guide_54

require 'yaml'

@c= YAML::load( File.open( 'omf_install.yaml' ) )

p @c



class String
  def red; colorize(self, "\e[1m\e[31m"); end
  def green; colorize(self, "\e[1m\e[32m"); end
  def dark_green; colorize(self, "\e[32m"); end
  def yellow; colorize(self, "\e[1m\e[33m"); end
  def blue; colorize(self, "\e[1m\e[34m"); end
  def dark_blue; colorize(self, "\e[34m"); end
  def pur; colorize(self, "\e[1m\e[35m"); end
  def colorize(text, color_code)  "#{color_code}#{text}\e[0m" end
end

def ok
  puts "[ "+"OK".green+" ]"
end

def failed
  puts "[ "+"FAILED".red+" ]"
end

def task(text)
  print "---> ".pur+text+"\t"
end

def check_root
  task("Checking User Name")
  if `whoami` == "root\n"
    ok
  else
    failed
    abort "This script must be run as root"
  end
end

def check_ubuntu_version
  task "Checking Ubuntu Version"
  if `cat /etc/issue`.include? "Ubuntu 11.04"
    ok
  else
    failed
    abort "This script will only work on Ubuntu 11.10"
  end
end

def check_interface
  task "Checking Network Interface #{@c['interface']}"
  i = `ifconfig #{@c['interface']}`
  if i.include? "10.0.0.191" or i.include? "UP"
    ok
  else
    failed
    abort "Please configure the node-facing network interface (#{@c['interface']}) "+ 
    "to use the IP address 10.0.0.200 with netmask 255.255.255.0"
  end
end

def install_packages(pkg)
  task "Installing packages '#{pkg}'\n"
  if system("apt-get install -y #{pkg}")
    ok
  else
    failed
    abort "Failed to install the packages '#{pkg}'"
  end
end 

def config_dnsmasq
  task "Configuring dnsmasq"
  File.open("/etc/dnsmasq.conf", 'a') {|f| 
    contents = <<EOF
    
# Added by OMF installer
interface=#{@c['interface']}
dhcp-range=#{@c['address_pool_prefix']}#{@c['address_pool_start']},#{@c['address_pool_prefix']}#{@c['address_pool_end']},255.255.255.0,12h
dhcp-option=3
dhcp-option=option:ntp-server,#{@c['controller_ip']}
dhcp-boot=net:control,pxelinux.0
enable-tftp
tftp-root=/tftpboot
EOF
    f.write(contents)
  }
  File.open("/etc/dnsmasq.d/omf_testbed.conf", 'w') {|f| 
    cnt = 1
    @c['macs'].each {|m|
      f.puts("dhcp-host=net:control,#{m},node#{cnt},#{@c['address_pool_prefix']}#{cnt}")
      cnt+=1 
    }
  }
  ok
end

puts "---> ".pur + "OMF #{@c['version']} Installation Script".dark_green
puts "---> ".pur + "Please report any issues to "+"omf-user@lists.nicta.com.au".red

check_root
check_ubuntu_version
check_interface
install_packages("syslinux dnsmasq ntp wget")
config_dnsmasq
