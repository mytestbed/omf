#!/usr/bin/env ruby

# OMF installation script

# This installation script assumes the testbed configuration as in the OMF 
# installation guide:
# http://mytestbed.net/projects/omf/wiki/Installation_Guide_54

require 'yaml'

@c= YAML::load( File.open( 'omf_install.yaml' ) )

@pxe_url = "http://pkg.mytestbed.net/files/#{@c['version']}/pxe/"

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
  puts "\t[ "+"OK".green+" ]"
end

def failed
  puts "\t[ "+"FAILED".red+" ]"
end

def task(text)
  print "---> ".pur+text
end

def replace_in_file(file, pattern, replacement)
  text = File.read(file)
  text.gsub!(/#{pattern}/,replacement)
  File.open(file, "w") {|f| f.write text}
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
  if system("/etc/init.d/dnsmasq restart")
    ok
  else
    failed
    abort "Failed to start dnsmasq. Please check the configuration files "+
      "manually. If you ran the OMF installer before, remove the OMF section "+
      "from /etc/dnsmasq.conf"
  end
end

def config_pxe
  task "Configuring PXE booting\n"
  system("mkdir -p /tftpboot/pxelinux.cfg; ln -s /usr/lib/syslinux/pxelinux.0 /tftpboot/")
  system("wget -N #{@pxe_url}#{@c['kernel_name']} -P /tftpboot")
  system("wget -N #{@pxe_url}#{@c['initramfs_name']} -P /tftpboot")
  File.open("/tftpboot/pxelinux.cfg/pxeconfig", 'w') {|f| 
    contents = <<EOF
SERIAL 0 19200 0
DEFAULT linux
LABEL linux
KERNEL #{@c['kernel_name']}
APPEND console=tty0 console=ttyS0,19200n8 vga=normal quiet root=/dev/ram0 rw load_ramdisk=1 prompt_ramdisk=1 ramdisk_size=32768 initrd=#{@c['initramfs_name']} control=#{@c['interface']} xmpp=#{@c['xmpp_domain']} slice=pxe_slice hrn=#{@c['hrn']} 
PROMPT 0
EOF
    f.write(contents)
  }
  File.open("/tftpboot/pxelinux.cfg/default", 'w') {|f| 
  contents = <<EOF
DEFAULT harddrive
LABEL harddrive
localboot 0
EOF
    f.write(contents)
  }
  ok
end

def install_xmpp
  task "Installing XMPP server"
  system("add-apt-repository ppa:ferramroberto/java; apt-get update; apt-get -y install sun-java6-jre")
  system("wget -N -P /tmp wget http://www.igniterealtime.org/downloadServlet?filename=openfire/openfire_3.7.1_all.deb")
  system("dpkg -i /tmp/downloadServlet?filename=openfire%2Fopenfire_3.7.1_all.deb")
  ok
end

def config_xmpp
  task "Configuring XMPP server\n\n"
  contents = <<EOF
* direct your web browser to 'http://#{@c['controller_ip']}:9090' and begin the setup wizard
* choose your language and click continue
* enter '#{@c['xmpp_domain']}' in the Domain field and click continue
* choose the embedded database. You can also use mysql, but you will have to create a mysql user and a database manually first.
* choose the default profile and click continue
* enter an admin password and click continue, then wait until the installation is finished
* log on to the web GUI at 'http://#{@c['controller_ip']}:9090' with the user/password you set in the wizard    
EOF
  puts contents
  puts "\nPlease follow the steps above. After you've set up Openfire, press any key to continue the OMF installation.".red  
  gets
  ok
end

def install_am
  task "Installing Aggregate Manager"
  File.open("/etc/apt/sources.list.d/omf.list", 'w') {|f| 
    f.write("deb http://pkg.mytestbed.net/ubuntu oneiric/")
  }
  system("apt-get update; apt-get install -y --allow-unauthenticated omf-aggmgr-5.4 oml2-server")
  ok
end

def config_am
  task "Configuring Aggregate Manager\n"
  system("cp /usr/share/doc/omf-aggmgr-5.4/examples/omf-aggmgr.yaml /etc/omf-aggmgr-5.4/")
  cmd = <<EOF
cd /etc/omf-aggmgr-5.4/enabled
ln -s ../available/cmcStub.yaml
ln -s ../available/frisbee.yaml
ln -s ../available/pxe.yaml
ln -s ../available/inventory.yaml
ln -s ../available/result.yaml
ln -s ../available/saveimage.yaml
EOF
  system(cmd)
  replace_in_file("/etc/omf-aggmgr-5.4/omf-aggmgr.yaml","  :server: \"norbit.npc.nicta.com.au\"","  :server: \"#{@c['xmpp_domain']}\"")
  replace_in_file("/etc/omf-aggmgr-5.4/available/saveimage.yaml","      saveimageIF: 10.0.0.200","      saveimageIF: #{@c['controller_ip']}")
  replace_in_file("/etc/omf-aggmgr-5.4/available/frisbee.yaml","      multicastIF: 10.0.0.200","      multicastIF: #{@c['controller_ip']}")
  ok
end

puts "---> ".pur + "OMF #{@c['version']} Installation Script".dark_green
puts "---> ".pur + "Please report any issues to "+"omf-user@lists.nicta.com.au".red

check_root
check_ubuntu_version
check_interface
#install_packages("syslinux dnsmasq ntp wget python-software-properties")
#config_dnsmasq
#config_pxe
#install_xmpp
#config_xmpp
#install_am
config_am
install_packages("mysql-server libdb4.6 phpmyadmin")