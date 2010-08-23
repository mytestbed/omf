#
# Test 2
#
# Testing 2 nodes in multiple groups running exec commandis for already installed apps
#

defProperty('res1', "node1", "ID of a node")
defProperty('res2', "node2", "ID of a node")

defGroup('Alice', property.res1)
defGroup('Bob', property.res2)
defGroup('Couple', "#{property.res1},#{property.res2}")
defGroup('GroupOfGroup', ["Alice", "Bob"])

onEvent(:ALL_UP) do |event|
  wait 5
  info "-------------"
  info "TEST - Group of 2 (res1,res2)"
  group("Couple").exec("/bin/hostname")
  wait 5
  info "---------------------"
  info "TEST - Group of Group ( (res1) and (res2) )"
  group("GroupOfGroup").exec("/bin/hostname")
  wait 5
  info "---------------"
  info "TEST - allGroup"
  allGroups.exec("/bin/hostname")
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

  # Test 02 is successfull if:
  # 1) each resource has been enrolled in all its groups as defined above
  # AND
  # 2) for each of the exec commands above, the log file has a message from 
  #    the AgentCommands module containing "DONE.OK"
  logfile = "#{property.logpath}/#{Experiment.ID}.log"
  lines = IO.readlines("#{logfile}")
  # 1)
  match1 = lines.grep(/is\ Enrolled/)
  result1 = (match1.length == 8) ? true : false
  # 2) 
  match1 = lines.grep(/DONE\.OK/)
  match2 = match1.grep(/AgentCommands/)
  result2 = (match2.length == 6) ? true : false

  return true if result1 && result2
  return false
end
