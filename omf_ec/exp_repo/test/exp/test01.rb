#
# Test 1
#
# Testing one node in one group running one exec command for an already installed app
#

defProperty('res1', "unconfigured-node-1", "ID of a node")
defProperty('res2', "unconfigured-node-2", "ID of a node")

defGroup('Actor', property.res1)

onEvent(:ALL_UP) do |event|
  wait 3
  info "TEST - allGroups"
  allGroups.exec("/bin/date")
  wait 3
  info "TEST - group"
  group("Actor").exec("/bin/hostname -f")
  wait 3
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

  # Test 01 is successfull if for each of the 2 exec commands above, the log 
  # file has a message from the AgentCommands module containing "DONE.OK"
  logfile = "#{property.logpath}/#{Experiment.ID}.log"
  lines = IO.readlines("#{logfile}")
  match1 = lines.grep(/DONE\.OK/)
  match2 = match1.grep(/AgentCommands/)
  result = (match2.length == 2) ? true : false
  return result
end
