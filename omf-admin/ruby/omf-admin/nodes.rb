require 'yaml'

class Nodes
  def initialize
    @@dbfile = 'nodes.yaml'
    @@nds = []
    load
  end
  
  def load
    if @@dummy
      if File.exists?(@@dbfile)
        @@nds = YAML.load_file(@@dbfile)
      else
        @@nds = [
          {'hostname' => 'node1', 'hrn' => 'omf.nicta.node1', 'control_mac' => '00:03:2d:0a:a3:d7',
            'control_ip' => '10.0.0.1', 'x' => '1', 'y' => '1', 'z' => '1', 'disk' => '/dev/sda',
            'testbed' => 'norbit'}
        ]
      end
    else
      nodes = OMF::Services.inventory.getAllNodes
      nodes.elements.each("ALLNODES/NODE"){|e|
        h = Hash.new
        e.attributes.each{|name,value|
          h[name]=value
        }
        @@nds << h
      }
    end
  end
  
  # try to guess the next free node ID
  def suggestID(testbed)
    load
    numbers = []
    @@nds.each{|n|
      if n['testbed'] == testbed
        num = (/\d+/).match(n['hostname'])
        numbers << num[0].to_i if !num.nil?
      end
    }
    numbers.sort!
    n = 1
    n = numbers.last+1 if !numbers.empty?
    return n
  end
  
  # return a list of all nodes
  def getAll(testbed = nil)
    load
    return @@nds if testbed.nil?
    ret = []
    @@nds.each{|n| ret << n if n['testbed'] == testbed}
    ret
  end
  
  # return the details of a specific node
  def get(hostname, testbed)
    load
    if !hostname.nil?
      # if the node exists, return it
      @@nds.each{|n|
        if n['hostname'] == hostname && n['testbed'] == testbed
          n['oldname'] = hostname
          return n 
        end
      }
    end
    # otherwise return a new, pre-filled node entry
    cfg = @@config.get
    nr = suggestID(testbed).to_s
    return {'hostname' => cfg[:nodes][:hostname][:value].dup.gsub!('%n', nr), 
            'hrn' => cfg[:nodes][:hrn][:value].dup.gsub!('%n', nr),
            'control_ip' => cfg[:nodes][:control_ip][:value].dup.gsub!('%n', nr), 'oldname' => ''}
  end

  # edit or add a node
  def edit(entry)
    return "Node hostname cannot be empty!" if entry['hostname'].empty?
    load
    doc = REXML::Element.new("NODE")
    doc.add_attributes(entry)
    if entry['oldname'].empty?
      # adding a new node
      @@nds.each{|n|
        return "'#{n['hostname']}' already exists!" if n['hostname'] == entry['hostname'] && n['testbed'] == entry['testbed']
      }
      result = OMF::Services.inventory.addNode(doc.to_s)
      return AM_ERROR if !XPath.match(result, "ADD_NODE/OK" )
    else
      # update an existing entry
      @@nds.collect! {|n|
        if n['hostname'] == entry['oldname']
          n = entry
          n.delete('oldname')
        end
        n
      }
    end
    saveDnsmasqConfig
    return "OK"
  end
  
  # delete a node
  def delete(hostname, testbed)
    load
    result = OMF::Services.inventory.removeNode(hostname,testbed)
    return AM_ERROR if !XPath.match(result, "REMOVE_NODE/OK" )
    saveDnsmasqConfig
  end
  
  # delete all nodes from a testbed
  def deleteAllFromTB(testbed)
    load
    # not implemented
    saveDnsmasqConfig
  end
  
  def saveDnsmasqConfig
    cfg = @@config.get
    file = cfg[:dnsmasq][:dhcpconfig][:value].dup
    begin
      File.open(cfg[:dnsmasq][:dhcpconfig][:value].dup, 'w') do |f|
        f.puts "# Do NOT modify this file manually!\n# It is auto-generated from the OMF inventory database."
        f.puts "# Add the line 'dhcp-hostsfile=#{file}' to your /etc/dnsmasq.conf to include this file."
        @@nds.each{ | n | 
          next if n['control_mac'].empty? || n['hostname'].empty? || n['control_ip'].empty? 
          f.puts "#{n['control_mac']},#{n['hostname']},#{n['control_ip']}" 
        }
      end
    rescue Exception => ex
      puts "Could not write to dnsmasq configuration file '#{file}'! Error: #{ex}"
    end
    # when dnsmasq receives SIGHUP it reloads the contents of files specified with 'dhcp-hostsfile'
    # in dnsmasq.conf
    system("killall -s HUP dnsmasq")
  end
  
end
