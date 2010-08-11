require 'yaml'

class Testbeds
  def initialize
    @@dbfile = 'testbeds.yaml'
    @@tb = nil
    load
  end
  
  def load
    if File.exists?(@@dbfile)
      @@tb = YAML.load_file(@@dbfile)
    else
      @@tb = [
        {'name' => "norbit"},
        {'name' => "planetlab"}
      ]
      save
    end
  end
  
  def save
    File.open(@@dbfile, 'w' ) do |out|
      YAML.dump(@@tb, out )
    end
  end
  
  def getAll
    @@tb
  end
  
  def edit(entry)
    return "Testbed name cannot be empty!" if entry['name'].empty?
    if entry['oldname'].empty?
      @@tb.each{|t|
        return "'#{t['name']}' already exists!" if t['name'] == entry['name']
      }
      # add a new entry
      @@tb << entry
    else
      # update an existing entry
      @@tb.collect! {|t|
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
    return "At least one testbed must be defined!" if @@tb.size == 1
    @@tb.delete_if {|t| t['name'] == name }
    @@nodes.deleteAllFromTB(name)
    save
    return "OK"
  end
  
end
