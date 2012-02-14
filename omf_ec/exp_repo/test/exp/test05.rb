#
# Test 5
#
# Testing one nodes in one group running a custom app
# Also testing all the possible bindings between app arguments and OMF
# Also testing app installation via TAR archive (containing the app and a payload data)
#

defProperty('res1', "unconfigured-node-1", "ID of a node")
defProperty('res2', "unconfigured-node-2", "ID of a node")
defProperty('pstring', "ABC", "1st string argument")
defProperty('pboolean', true, "1st boolean argument")
defProperty('pinteger', 123, "1st integer argument")

defApplication('myAppURI', 'myAppName') { |app|
  app.path = "/usr/bin/myApp"
  app.appPackage = "http://omf.mytestbed.net/myApp.tar"

  app.defProperty('arg1','Argument 1', '-s', {:order => 1, :type => :string, :dynamic => true})
  app.defProperty('arg2','Argument 2', '--arg2', {:type => :string, :dynamic => false})
  app.defProperty('arg3','Argument 3', '-b', {:type => :boolean, :dynamic => false})
  app.defProperty('arg4','Argument 4', '--arg4', {:type => :boolean, :dynamic => true})
  app.defProperty('arg5','Argument 5', '--arg5', {:type => :boolean, :dynamic => false})
  app.defProperty('arg6','Argument 6', '-i', {:order => 2, :type => :integer, :dynamic => false})
  app.defProperty('arg7','Argument 7', '--arg7', {:type => :integer, :dynamic => true})
  app.defProperty('arg8','Argument 8', nil, {:type => :string, :dynamic => true})
  app.defProperty('arg9','Argument 9', nil, {:type => :integer, :dynamic => false})
}

defGroup('Actor', property.res1) {|n|
  n.addApplication("myAppURI") {|app|
    app.setProperty('arg1', property.pstring)  # Displays "-s ABC" in first position!
    app.setProperty('arg2', 'DEF') # Displays "--arg2 DEF"
    app.setProperty('arg3', property.pboolean) # Displays "-b"
    app.setProperty('arg4', true) # Displays "--arg4"
    app.setProperty('arg5', false) # Displays nothing 
    app.setProperty('arg6', property.pinteger) # Displays "-i 123" in second position!
    app.setProperty('arg7', 456) # Displays "--arg7 456"
    app.setProperty('arg8', "ZZZ") # Displays "ZZZ"
    app.setProperty('arg9', 000) # Displays "0"
  }
}

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  wait 5
  allGroups.startApplications
  wait 5
  Experiment.done
end


#
# Checking the Execution
# Here you do whatever is required to check that the above experiment went well
# Then return true if you decided that it did, or false otherwise
#
# Experiment log file is at: property.logpath
# Also you may want to look at system:exp:testlib
#

def check_outcome

  # Test 03 is successfull if all of the following are true:
  # 1) the tarball is installed OK AND the application runs OK 
  # 2) the application outputs the correct payload from the tarball 
  # 3) the application accepts and outputs the correct arguments
  logfile = "#{property.logpath}/#{Experiment.ID}.log"
  lines = IO.readlines("#{logfile}")
  # 1)
  match1 = lines.grep(/APP_EVENT\ STARTED/)
  r1 = (match1.length == 2) ? true : false
  match1 = lines.grep(/APP_EVENT DONE\.OK/)
  match2 = match1.grep(/AgentCommands/)
  r2 = (match2.length == 2) ? true : false
  # 2)
  match1 = lines.grep(/PAYLOAD\-1234567890\-PAYLOAD/)
  match2 = match1.grep(/AgentCommands/)
  r3 = (match2.length == 1) ? true : false
  match1 = lines.grep(/\-s\ ABC\ \-i\ 123\ \-\-arg7\ 456\ \-b\ ZZZ\ 0\ \-\-arg4\ \-\-arg2\ DEF/)
  match2 = match1.grep(/AgentCommands/)
  r4 = (match2.length == 1) ? true : false

  puts "Check Outcome [r1:#{r1} - r2:#{r2} - r3:#{r3} - r4:#{r4}]" 
  return true if r1 && r2 && r3 && r4
  return false

end
