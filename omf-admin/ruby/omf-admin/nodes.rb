require 'yaml'

class Nodes
  def initialize
    @@dbfile = 'nodes.yaml'
    @@nds = nil
    load
  end
  
  def load
    if File.exists?(@@dbfile)
      @@nds = YAML.load_file(@@dbfile)
    else
      @@nds = [
        {'name' => 'node1', 'hrn' => 'omf.nicta.node1', 'control_mac' => '00:03:2d:0a:a3:d7',
          'control_ip' => '10.0.0.1', 'x' => '1', 'y' => '1', 'z' => '1', 'disk' => '/dev/sda',
          'testbed' => 'norbit'}
      ]
    end
  end
  
  def save
    File.open(@@dbfile, 'w' ) do |out|
      YAML.dump(@@nds, out )
    end
  end
  
  def suggestID
    numbers = []
    @@nds.each{|n|
      num = (/\d+/).match(n['name'])
      numbers << num[0].to_i if !num.nil?
    }
    numbers.sort!
    n = 1
    if !numbers.empty?
      n = numbers.last+1
    end
    return n
  end
  
  
  def getAll
    @@nds
  end
  
  def get(name)
    cfg = @@config.get
    newnode = {'name' => cfg[:nodes][:name][:value].dup, 'hrn' => cfg[:nodes][:hrn][:value].dup,
               'control_ip' => cfg[:nodes][:control_ip][:value].dup, 'oldname' => ''}
    nr = suggestID.to_s
    p newnode
    newnode['name'].gsub!('%n', nr)
    newnode['hrn'].gsub!('%n', nr)
    newnode['control_ip'].gsub!('%n', nr)

    if name.nil? || name.empty?
      return newnode
    else
      @@nds.each{|n|
        if n['name'] == name
          n['oldname'] == name
          return n 
        end
      }
      return newnode
    end
  end
  
  def edit(entry)
    return "Node name cannot be empty!" if entry['name'].empty?
    if entry['oldname'].empty?
      @@nds.each{|t|
        return "'#{t['name']}' already exists!" if t['name'] == entry['name']
      }
      # add a new entry
      @@nds << entry
    else
      # update an existing entry
      @@nds.collect! {|t|
        if t['name'] == entry['oldname']
          t = entry
          t.delete('oldname')
        end
        t
      }
    end
    save
    return "OK"
  end
  
  def delete(name)
    @@nds.delete_if {|t| t['name'] == name }
    save
  end
  
end
