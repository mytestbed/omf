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
        :webinterface => {
          :port => {:desc => "Port used by the web interface (requires restart of the omf-admin daemon)", :value => 5454},
          :rdir => {:desc => 'Resource directory containing the CSS', :value => '/usr/share/omf-common-5.3/share/htdocs'}
        },
        :communication => {
          :xmppserver => {:desc => "XMPP Server", :value => "norbit.npc.nicta.com.au"}
        },      
        :dnsmasq => {
          :dnslog0 => {:desc => "Dnsmasq logfile", :value =>"/var/log/syslog"},
          :dnslog1 => {:desc => "Old Dnsmasq logfile (after log rotation)", :value =>"/var/log/syslog.1"},
          :dhcpconfig => {:desc => "Dnsmasq additional configuration file (where static DHCP assignments are stored)", :value =>"dnsmasq_omf.conf"}
        },      
        :nodes => {
          :name => {:desc => "Node name format (%n will be replaced by an ID number)", :value =>"node%n"},
          :hrn => {:desc => "HRN format (%n will be replaced by an ID number)", :value =>"omf.nicta.node%n"},
          :control_ip => {:desc => "Control IP address format (%n will be replaced by an ID number)", :value =>"10.0.0.%n"}
        }
      }
      save
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
