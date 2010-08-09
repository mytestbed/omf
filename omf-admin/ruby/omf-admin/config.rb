require 'yaml'

class AdminConfig
  def initialize
    @@cfgfile = '../../etc/omf-admin/omf-admin.yaml'
    @@config = nil
    load
  end
  
  def load
    if File.exists?(@@cfgfile)
      @@config = YAML.load_file(@@cfgfile)
    else
      @@config = {
        :communication => {
          :xmppserver => {:desc => "XMPP Server", :value => "norbit.npc.nicta.com.au"}
        },      
        :dnsmasq => {
          :dnslog0 => {:desc => "Dnsmasq logfile", :value =>"/var/log/syslog"},
          :dnslog1 => {:desc => "Old Dnsmasq logfile (after log rotation)", :value =>"/var/log/syslog.1"},
          :dhcpconfig => {:desc => "Dnsmasq additional configuration file (where static DHCP assignments are stored)", :value =>"/etc/dnsmasq_omf.conf"}
        },      
        :nodes => {
          :node_format => {:desc => "Node name format (%n will be replaced by an ID number)", :value =>"node%n"},
          :hrn_format => {:desc => "HRN format (%n will be replaced by an ID number)", :value =>"omf.nicta.node%n"},
          :controlip_format => {:desc => "Control IP address format (%n will be replaced by an ID number)", :value =>"10.0.0.%n"},
          :default_disk => {:desc => "Default disk for loading/saving images", :value =>"/dev/sda"},
        }
      }
    end
  end
  
  def save
    File.open(@@cfgfile, 'w' ) do |out|
      YAML.dump(@@config, out )
    end
  end
  
  def get
    @@config
  end
  
  def set(newconfig)
    @@config.merge!(newconfig)
  end
  
end
