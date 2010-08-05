require "sequel"

class NodeDB

  # connect to an in-memory database
  DB = Sequel.sqlite('node.db')

  # create an items table
  DB.create_table :items do
    primary_key :id
    String :hostname
    String :hrn
    String :control_ip
    String :control_mac  
  end

  # create a dataset from the items table
  items = DB[:items]

  # populate the table
  #items.insert(:hostname => 'node1', :control_mac => '00:1b:2f:c2:c9:a1')

  # print out the number of records
  #puts "Item count: #{items.count}"

  #puts DB[:items].filter(:control_mac => '00:1b:2f:c2:c9:a1').get(:hostname)
  
  def getAllNodes
    DB[:items].all
  end
  
  def addNode
  end
  
  def editNode
  end
  
  def removeNode
  end
  
end