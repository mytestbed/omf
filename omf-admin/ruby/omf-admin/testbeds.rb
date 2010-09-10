class Testbeds
  def initialize
    @@tb = []
    load
    @@currentTB = @@tb.first['name']
  end
  
  def load
    @@tb = []
    testbeds = OMF::Services.inventory.getAllTestbeds
    testbeds.elements.each("ALLTESTBEDS/TESTBED"){|e|        
      @@tb << {'name' => "#{e.text}"}
    }
  end
  
  def getAll
    load
    @@tb
  end
  
  def edit(entry)
    return "Testbed name cannot be empty!" if entry['name'].empty?
    load
    if @@tb.include?({'name' => "#{entry['oldname']}"})
      # update an existing entry
      return "OK" if entry['oldname'] == entry['name']
      result = OMF::Services.inventory.editTestbed(entry['oldname'],entry['name'])
      return AM_ERROR if !XPath.match(result, "EDIT_TESTBED/OK" )
    else
      @@tb.each{|t|
        return "'#{t['name']}' already exists!" if t['name'] == entry['name']
      }
      result = OMF::Services.inventory.addTestbed(entry['name'])
      return AM_ERROR if !XPath.match(result, "ADD_TESTBED/OK" )
    end
    return "OK"
  end
  
  def delete(name)
    load
    return "At least one testbed must be defined!" if @@tb.size == 1
    return "Testbed '#{name}' does not exist!" if !@@tb.include?({'name' => "#{name}"})
    result = OMF::Services.inventory.removeTestbed(name)
    return AM_ERROR if !XPath.match(result, "REMOVE_TESTBED/OK" )
    return "OK"
  end
  
end
