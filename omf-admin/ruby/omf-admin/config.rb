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
      xmppserver = Hash["description","d","value","v"]
      amid = Hash["description","d","value","v"]
      communication = Hash["xmppserver",xmppserver,"amid",amid]

      dnslog0 = Hash["description","d","value","v"]
      dnslog1 = Hash["description","d","value","v"]
      dnsmasq = Hash["dnslog0",dnslog0,"dnslog1",dnslog1]

      @@config = Hash["communication",communication, "dnsmasq",dnsmasq]
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
  
end
