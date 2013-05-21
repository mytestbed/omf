# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

#
# Test 6
#
# Testing one nodes in one group running a third party app
# Also testing app installation via APT-GET
#

defProperty('res1', "unconfigured-node-1", "ID of a node")
defProperty('res2', "unconfigured-node-2", "ID of a node")

defApplication('nmapURI', 'nmap') { |app|
  app.path = "/usr/bin/nmap"
  app.debPackage = "nmap"

  app.defProperty('target','Host to scan', '--target', {:order => 1, :use_name => false, :type => :string, :dynamic => false})
  app.defProperty('port','Port to scan', '-p', {:order => 2, :type => :string, :dynamic => false})
}

defGroup('Actor', property.res1) {|n|
  n.addApplication("nmapURI") {|app|
    app.setProperty('target', "127.0.0.1")
    app.setProperty('port', '101-200')
  }
}

onEvent(:ALL_UP_AND_INSTALLED) do |event|
  wait 5
  allGroups.startApplications
  wait 10
  # clean:
  rm = "LANGUAGE='C' LANG='C' LC_ALL='C' DEBIAN_FRONTEND='noninteractive' "+
       "apt-get remove nmap -qq -y"
  allGroups.exec(rm)
  wait 10
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

  # Test 06 is successfull if:
  # 1) the application nmap has been unpacked on the resource
  # AND
  # 2) for the Actor group, the log file has a message from the AgentCommands
  #    module containing "DONE.OK" for the install of the app, and for the app
  #    execution

  # Test 06 is successfull if for each of the 2 exec commands above, the log
  # file has a message from the AgentCommands module containing "DONE.OK"
  logfile = "#{property.logpath}/#{Experiment.ID}.log"
  lines = IO.readlines("#{logfile}")
  # 1)
  match1 = lines.grep(/Unpacking\ nmap/)
  match2 = match1.grep(/AgentCommands/)
  result1 = (match2.length == 1) ? true : false
  # 2)
  match1 = lines.grep(/DONE\.OK/)
  match2 = match1.grep(/AgentCommands/)
  result2 = (match2.length >= 2) ? true : false

  return true if result1 && result2
  return false
end
