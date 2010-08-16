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
          {'name' => 'node1', 'hrn' => 'omf.nicta.node1', 'control_mac' => '00:03:2d:0a:a3:d7',
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
  
  def save
    if @@dummy
      File.open(@@dbfile, 'w' ) do |out|
        YAML.dump(@@nds, out )
      end
    else
      # here
    end
    saveDnsmasqConfig
  end
  
  # try to guess the next free node ID
  def suggestID(testbed)
    numbers = []
    @@nds.each{|n|
      if n['testbed'] == testbed
        num = (/\d+/).match(n['name'])
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
    return @@nds if testbed.nil?
    ret = []
    @@nds.each{|n| ret << n if n['testbed'] == testbed}
    ret
  end
  
  # return the details of a specific node
  def get(name, testbed)
    if !name.nil?
      # if the node exists, return it
      @@nds.each{|n|
        if n['name'] == name && n['testbed'] == testbed
          n['oldname'] = name
          return n 
        end
      }
    end
    # otherwise return a new, pre-filled node entry
    cfg = @@config.get
    nr = suggestID(testbed).to_s
    return {'name' => cfg[:nodes][:name][:value].dup.gsub!('%n', nr), 
            'hrn' => cfg[:nodes][:hrn][:value].dup.gsub!('%n', nr),
            'control_ip' => cfg[:nodes][:control_ip][:value].dup.gsub!('%n', nr), 'oldname' => ''}
  end

  # edit or add a node
  def edit(entry)
    return "Node name cannot be empty!" if entry['name'].empty?
    if entry['oldname'].empty?
      # adding a new node
      @@nds.each{|n|
        return "'#{n['name']}' already exists!" if n['name'] == entry['name'] && n['testbed'] == entry['testbed']
      }
      @@nds << entry
    else
      # update an existing entry
      @@nds.collect! {|n|
        if n['name'] == entry['oldname']
          n = entry
          n.delete('oldname')
        end
        n
      }
    end
    save
    return "OK"
  end
  
  # delete a node
  def delete(name, testbed)
    @@nds.delete_if {|t| t['name'] == name && t['testbed'] == testbed }
    save
  end
  
  # delete all nodes from a testbed
  def deleteAllFromTB(testbed)
    @@nds.delete_if {|t| t['testbed'] == testbed }
    save
  end
  
  def saveDnsmasqConfig
    cfg = @@config.get
    file = cfg[:dnsmasq][:dhcpconfig][:value].dup
    begin
      File.open(cfg[:dnsmasq][:dhcpconfig][:value].dup, 'w') do |f|
        f.puts "# Do NOT modify this file manually!\n# It is auto-generated from the OMF inventory database."
        f.puts "# Add the line 'dhcp-hostsfile=#{file}' to your /etc/dnsmasq.conf to include this file."
        @@nds.each{ | n | 
          next if n['control_mac'].empty? || n['name'].empty? || n['control_ip'].empty? 
          f.puts "#{n['control_mac']},#{n['name']},#{n['control_ip']}" 
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
