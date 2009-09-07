#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
# = agentCommands.rb
#
# == Description
#
# This module contains all the commands understood by an agent
# Any change to the sematics of the commands, or the addition
# of new ones should be reflected in a change of the
# PROTOCOL_VERSION.
#

require 'omf-common/mobject'
require 'omf-common/execApp'
#require 'omf-resctl/omf_driver/aironet'
require 'omf-resctl/omf_driver/ethernet'

module AgentCommands

  # Version of the communication protocol between the NH and the NAs
  PROTOCOL_VERSION = "4.2"

  # TODO:
  # For GEC4 demo we use these Constant values.
  # When we will integrate a virtualization scheme, coupled with a 
  # Resource Manager (RM) and a Resource Controller (RC), we might want to have these
  # config values passed as parameters (i.e. different RC in different sliver might
  # need different configs). This will probably depend on the selected virtualization scheme 
  #
  # Slave Resource Controller (aka NodeAgent)
  SLAVE_RESCTL_ID = "SLAVE-RESOURCE-CTL"
  SLAVE_RESCTL_LISTENIF = "lo" # Slave Agent listens only on localhost interface
  SLAVE_RESCTL_LISTENPORT = 9026
  SLAVE_RESCTL_CMD = "sudo /usr/sbin/omf-resctl"
  SLAVE_RESCTL_LOG = "/etc/omf-resctl/nodeagentSlave_log.xml"
  # Slave Experimet Controller (aka NodeHandler)
  SLAVE_EXPCTL_ID = "SLAVE-EXP-CTL"
  SLAVE_EXPCTL_CMD = "/usr/bin/omf exec"
  SLAVE_EXPCTL_CFG = "/etc/omf-expctl/nodehandlerSlave.yaml"
  # Proxy OML Collection Server
  OML_PROXY_ID = "PROXY-OML-SERVER"
  OML_PROXY_CMD = "/usr/bin/oml2-proxy-server"
  OML_PROXY_LISTENPORT = "8002"
  OML_PROXY_LISTENADDR = "localhost"
  OML_PROXY_CACHE = "/tmp/temp-proxy-cache"
  OML_PROXY_LOG = "/tmp/temp-proxy-log"
  
  # Mapping between OMF's device name and Linux's device name
  DEV_MAPPINGS = {
    'net/e0' => EthernetDevice.new('net/e0', 'eth0'),
    'net/e1' => EthernetDevice.new('net/e1', 'eth1'),
    #'net/w2' => AironetDevice.new('net/w2', 'eth2')
  }

  # Code Version of this NA
  VERSION = "$Revision: 1273 $".split(":")[1].chomp("$").strip
  SYSTEM_ID = :system

  # File containing image name
  IMAGE_NAME_FILE = '/.orbit_image'

  # 
  # Return the Application ID for the OML Proxy Collection Server
  # (This is only set when NA is involved in an experiment that support
  # temporary disconnection of node/resource from the Control Network)
  #
  # [Return] an Application ID (String)
  #
  def AgentCommands.omlProxyID
    return OML_PROXY_ID
  end

  # 
  # Return the Application ID for the 'slave' Experiment Controller (aka 
  # NodeHandler) running on this node/resource.
  # (This is only set when NA is involved in an experiment that support
  # temporary disconnection of node/resource from the Control Network)
  #
  # [Return] an Application ID (String)
  #
  def AgentCommands.slaveExpCtlID
    return SLAVE_EXPCTL_ID
  end

  #
  # Command 'SET_MACTABLE'
  #
  # Add a given MAC address to the MAC filtering table of 
  # this node. Any frames from this MAC address will be dropped
  #
  # - agent = the instance of this NA
  # - cmdToUse = which filtering tool to use, supported options are 'iptable' or 'ebtable' or 'mackill'
  # - mac = MAC address to block
  #
  def AgentCommands.SET_MACTABLE(agent, argArray)
    # retrieve arguments
    cmdToUse = getArg(argArray, "MAC Filtering Command to Use")
    macToBlock = getArg(argArray, "MAC Address to Block")
    # Current madwifi change first octet from 00 to 06 when using 'wlanconfig create' at Winlab
    # Fix that by blocking it as well.
    macToBlockBis = "06:"+macToBlock.slice(3..-1)
    # retrieve command line to execute in order to block this MAC addr.
    case cmdToUse
      when "iptable"
	cmd = "iptables -A INPUT -m mac --mac-source #{macToBlock} -j DROP ; iptables -A INPUT -m mac --mac-source #{macToBlockBis} -j DROP"
        cmd2 = ''
      when "ebtable"
	cmd = "ebtables -A INPUT --source #{macToBlock} -j DROP ; ebtables -A INPUT --source #{macToBlockBis} -j DROP"
        cmd2 = ''
      when "mackill"
	cmd = "echo - #{macToBlock} > /proc/net/mackill ; echo - #{macToBlockBis} > /proc/net/mackill" 
        cmd2 = "sudo chmod 666 /proc/net/mackill ; echo \"-#{macToBlock}\">/proc/net/mackill ; echo \"-#{macToBlockBis}\">/proc/net/mackill"
      else 
        MObject.error "SET_MACTABLE - Unknown command to use: #{cmdToUse}"
	agent.errorReply(:SET_MACTABLE, agent.agentName, "Unsupported command: #{cmdToUse}")
	return
    end
    # execute the command...
    MObject.debug "Exec: '#{cmd}'"
    result=`#{cmd}`
    # check if all went well
    if ! $?.success?
      # if not, and if an alternate method was set, try again with the alternate one
      if (cmd2 != '')
        MObject.error "SET_MACTABLE - Trying again using alternate cmd: #{cmd2}"
        MObject.debug "Exec: '#{cmd2}'"
        result=`#{cmd2}`
      end
      # check if all went well - Report error only for original cmd
      if ! $?.success?
        MObject.error "SET_MACTABLE - Error executing cmd: #{cmd}"
        agent.errorReply(:SET_MACTABLE, agent.agentName, "Executing cmd: '#{cmd}'")
	return
      end
    end
    agent.okReply(:SET_MACTABLE)
  end

  #
  # Command 'ALIAS'
  #
  # Set additional alias names for this node
  #
  # - agent = the instance of this NA
  # - argArray = an array with the list of name to add as aliases
  #
  def AgentCommands.ALIAS(agent, argArray)
    argArray.each{ |name|
      agent.addAlias(name)
    }
  end

  #
  # Command 'YOUARE'
  # 
  # Initial enroll message received from the NH
  #
  # - agent = the instance of this NA
  # - argArray = an array with the optional enroll parameters
  #
  def AgentCommands.YOUARE(agent, argArray)
    # delete session and experiment IDs
    argArray.delete_at(0)
    argArray.delete_at(0)    
    agentId = getArg(argArray, "Name of agent")
    agent.addAlias(agentId, true)
    argArray.each{ |name|
      agent.addAlias(name)
    }
    # The ID of a node (for the moment [x,y]) should be taken form here, and not from the IP address of the Control Interface!
    x = agentId.split("_")[1]
    y = agentId.split("_")[2]
    agent.communicator.setX(eval(x))
    agent.communicator.setY(eval(y))
    agent.okReply(:YOUARE)
  end

  #
  # Command 'SET_DISCONNECT'
  # 
  # Activate the 'Disconnection Mode' for this NA. In this mode, this NA will assume
  # the role of a 'master' NA. It will fetch a copy of the experiment description from
  # the main 'master' NH. Then it will execute a Proxy OML server, a 'slave' NA and
  # a 'slave' NH. Finally, it will monitor the 'slave' NH, and upon its termination, 
  # it will initiate the final measurement collection (OML proxy to OML server), and
  # the end of the experiment.
  #
  # - agent = the instance of this NA
  # - argArray = an array with the following parameters: the experiment ID, the URL
  #              from where to get the experiment description, the address of the 
  #              OML Server, the port of the OML server
  #
  def AgentCommands.SET_DISCONNECT(agent, argArray)
    agent.allowDisconnection
    
    # Fetch the Experiment ID from the NH
    expID = getArg(argArray, "Experiment ID")

    # Fetch the Experiment Description from the NH
    ts = DateTime.now.strftime("%F-%T").split(%r{[:-]}).join('_')
    urlED = getArg(argArray, "URL for Experiment Description")
    fileName = "/tmp/exp_#{ts}.rb"
    MObject.debug("Fetching Experiment Description at '#{urlED}'")
    if (! system("wget -m -nd -q -O #{fileName} #{urlED}"))
      raise "Couldn't fetch Experiment Description at:' #{urlED}'"
    end
    MObject.debug("Experiment Description saved at: '#{fileName}'")

    # Fetch the addr:port of the OML Collection Server from the NH
    addrMasterOML = getArg(argArray, "Address of Master OML Server")
    portMasterOML = getArg(argArray, "Port of Master OML Server")

    # Now Start a Proxy OML Server
    cmd = "#{OML_PROXY_CMD} --listen #{OML_PROXY_LISTENPORT} \
                            --dstport #{portMasterOML} \
                            --dstaddress #{addrMasterOML}\
                            --resultfile #{OML_PROXY_CACHE} \
                            --logfile #{OML_PROXY_LOG}"
    MObject.debug("Starting OML Proxy Server with: '#{cmd}'")
    ExecApp.new(OML_PROXY_ID, agent, cmd)

    # Now Start a Slave NodeAgent with its communication module in 'TCP Server' mode
    # Example: sudo /usr/sbin/omf-resctl --server-port 9026 --local-if lo --log ./nodeagentSlave_log.xml
    cmd = "#{SLAVE_RESCTL_CMD}  --server-port #{SLAVE_RESCTL_LISTENPORT} \
                                --local-if #{SLAVE_RESCTL_LISTENIF} \
                                --log #{SLAVE_RESCTL_LOG}"
    MObject.debug("Starting Slave Resouce Controller (NA) with: '#{cmd}'")
    ExecApp.new(SLAVE_RESCTL_ID, agent, cmd)
    
    # Now Start a Slave NodeHandler with its communication module in 'TCP Client' mode
    cmd = "#{SLAVE_EXPCTL_CMD} --config #{SLAVE_EXPCTL_CFG} \
                               --slave-mode #{expID} \
                               --slave-mode-omlport #{OML_PROXY_LISTENPORT} \
                               --slave-mode-omladdr #{OML_PROXY_LISTENADDR} \
                               --slave-mode-xcoord #{agent.x} \
                               --slave-mode-ycoord #{agent.y} \
                               #{fileName}"
    MObject.debug("Starting Slave Experiment Controller (NH) with: '#{cmd}'")
    ExecApp.new(SLAVE_EXPCTL_ID, agent, cmd)
    
  end

  #
  # Command 'EXEC'
  #
  # Execute a program on the machine running this NA
  #
  # - agent = the instance of this NA
  # - argArray = an array with the complete command line of the program to execute
  #
  def AgentCommands.EXEC(agent, argArray)
    id = getArg(argArray, "ID of install")

    args = [] # potentially substitute arguments
    argArray.each { |arg|
      if (arg[0] == ?%)
        # if arg starts with "%" perform certain substitutions
        arg = arg[1..-1]  # strip off leading '%'
        arg.sub!(/%x/, agent.x.to_s)
        arg.sub!(/%y/, agent.y.to_s)
        arg.sub!(/%n/, agent.agentName)
      end
      if arg =~ /^OML_CONFIG=.*:/
        # OML can't fetch config file over the net, need to download it first
        url = arg.split('=')[1..-1].join('=')
        # this is overkill, but so what
        require 'digest/md5'
        fileName = "/tmp/#{Digest::MD5.hexdigest(url)}.xml"
        MObject.debug("Fetching oml definition file ", url)
        if (! system("wget -m -nd -q -O #{fileName} #{url}"))
          raise "Couldn't fetch OML config file #{url}"
        end
        arg = "OML_CONFIG=#{fileName}"
      end
      args << arg
    }
    cmd = args.join(' ')
    ExecApp.new(id, agent, cmd)
  end

  #
  # Command 'EXECUTE'
  #
  # Execute a program on the machine running this NA
  #
  # - agent = the instance of this NA
  # - cmdObject = a Command Object holding all the information required to 
  #               execute the program (e.g. command line, path, etc...)
  #
  def AgentCommands.EXECUTE(agent, cmdObject)
    id = cmdObject.procID
    fullCmdLine = "#{cmdObject.path} #{cmdObject.cmdLineArgs}"
    MObject.info "TDEBUG - EXECUTE - '#{fullCmdLine}'"
    ExecApp.new(id, agent, fullCmdLine)
  end

  #
  # Command 'KILL'
  #
  # Send a signal to a process running on this node
  #
  # - agent = the instance of this NA
  # - argArray = an array with the ID of the process and the type of signal to send
  #
  def AgentCommands.KILL(agent, argArray)
    id = getArg(argArray, "ID of process")
    signal = getArgDefault(argArray, "KILL")
    ExecApp[id].kill(signal)
  end

  #
  # Command 'STDIN'
  #
  # Send a line of text to the STDIN of a process
  #
  # - agent = the instance of this NA
  # - argArray = an array with the ID of the process and the texxt to send
  #
  def AgentCommands.STDIN(agent, argArray)
    begin
      id = getArg(argArray, "ID of process")
      line = argArray.join(' ')
      ExecApp[id].stdin(line)
    rescue Exception => err
      raise Exception.new("- Error while writing to standard-IN of application '#{id}' \
(likely caused by a a call to 'sendMessage' or an update to a dynamic property)") 
    end
  end

  #
  # Command 'EXIT'
  #
  # Terminate an application running on this node
  # First try to send the message 'exit' on the app's STDIN
  # If no succes, then send a Kill signal to the process
  #
  # - agent = the instance of this NA
  # - argArray = an array with the ID of the process
  #
  def AgentCommands.EXIT(agent, argArray)
    id = getArg(argArray, "ID of process")
    begin
      # First try sending 'exit' on the app's STDIN
      MObject.debug("Sending 'exit' message to STDIN of application: #{id}")
      ExecApp[id].stdin('exit')
      # If apps still exists after 4sec...
      sleep 4
      if ExecApp[id] != nil
        MObject.debug("Sending 'kill' signal to application: #{id}")
        ExecApp[id].kill('KILL')
      end
    rescue Exception => err
      raise Exception.new("- Error while terminating application '#{id}' - #{err}")
    end
  end

  #
  # Command 'PM_INSTALL'
  #
  # Poor man's installer. Fetch a tar file and
  # extract it into a specified directory
  #
  # - agent = the instance of this NA
  # - argArray = an array with the install ID (for reporting progress), the URL of the tar file, and the destination path
  #
  def AgentCommands.PM_INSTALL(agent, argArray)
    id = getArg(argArray, "ID of install")
    url = getArg(argArray, "URL of program to install")
    installRoot = getArgDefault(argArray, "/")

    MObject.debug "Installing #{url} into #{installRoot}"
    cmd = "cd /tmp;wget -m -nd -q #{url};"
    file = url.split('/')[-1]
    cmd += "tar -C #{installRoot} -xf #{file}; rm #{file}"
    ExecApp.new(id, agent, cmd)
  end

  #
  # Command 'APT'
  #
  # Execute apt-get command on node
  #
  # - agent = the instance of this NA
  # - argArray = an array with the install ID (for reporting progress), the apt-get parameters, and the package name
  #
  def AgentCommands.APT_INSTALL(agent, argArray)
    id = getArg(argArray, "ID of install")
    command = getArg(argArray, "Command to apt-get")
    pkgName = getArg(argArray, "Name of package to install")

    cmd = "apt-get -q -y #{argArray.join(' ')} #{command} #{pkgName}"
    ExecApp.new(id, agent, cmd)
  end

  #
  # Command 'RESET'
  #
  # Reset this node agent
  #
  # - agent = the instance of this NA
  # - argArray = an empty array 
  #
  def AgentCommands.RESET(agent, argArray)
    agent.reset
  end


  #
  # Command 'RESTART'
  #
  # Restart this node agent
  #
  # - agent = the instance of this NA
  # - argArray = an empty array 
  #
  def AgentCommands.RESTART(agent, argArray)
    agent.communicator.quit
    ExecApp.killAll
    system('/etc/init.d/omf-resctl restart')
    # will be killed by now :(
  end

  #
  # Command 'REBOOT'
  # 
  # Reboot this node
  #
  # - agent = the instance of this NA
  # - argArray = an empty array 
  #
  def AgentCommands.REBOOT(agent, argArray)
    agent.send(:STATUS, SYSTEM_ID, "REBOOTING")
    agent.communicator.quit
    cmd = `sudo /sbin/reboot`
    if !$?.success?
      # In case 'sudo' is not installed but we do have root rights (e.g. PXE image)
      cmd = `/sbin/reboot`
    end
  end

  #
  # Command 'MODPROBE'
  #
  # Load a kernel module on this node
  #
  # - agent = the instance of this NA
  # - argArray = an array with the name of the module to load
  #
  def AgentCommands.MODPROBE(agent, argArray)
    moduleName = getArg(argArray, "Name of module to probe")
    id = "module/#{moduleName}"
    ExecApp.new(id, agent, "/sbin/modprobe #{argArray.join(' ')} #{moduleName}")
  end

  #
  # Command 'CONFIGURE'
  #
  # Configure a system parameter on this node
  #
  # - agent = the instance of this NA
  # - argArray = an array with the name (as a Path) of the parameter to configure and its value
  #
  def AgentCommands.CONFIGURE(agent, argArray)
    path = getArg(argArray, "Name of parameter as path")
    value = getArgDefault(argArray)

   if (type, id, prop = path.split("/")).length != 3
     raise "Expected path '#{path}' to contain three levels"
   end

   device = DEV_MAPPINGS["#{type}/#{id}"]
   if (device == nil)
     raise "Unknown resource '#{type}/#{id}' in 'configure'"
   end

   device.configure(agent, prop, value)
  end

  #
  # Command 'LOAD_NODE'
  #
  # Load a specified disk image onto this node through frisbee
  #
  # - agent = the instance of this NA
  # - argArray = an array with the frisbee address+port to use, and the name of the disk device to image
  #
  def AgentCommands.LOAD_IMAGE(agent, argArray)
    mcAddress = getArg(argArray, "Multicast address")
    mcPort = getArg(argArray, "Multicast port")
    disk = getArgDefault(argArray, "/dev/hda")

    MObject.info "AgentCommands", "Frisbee image from ", mcAddress, ":", mcPort
    ip = agent.localAddr
    cmd = "frisbee -i #{ip} -m #{mcAddress} -p #{mcPort} #{disk}"
    MObject.debug "AgentCommands", "Frisbee command: ", cmd
    ExecApp.new('builtin:load_image', agent, cmd, true)
  end

  #
  # Command 'SAVE_NODE'
  #
  # Save the image of this node with frisbee and send
  # it to the image server.
  #
  # - agent = the instance of this NA
  # - argArray = an array with the host of the file server, the image name, and the name of the disk device to save
  #
  def AgentCommands.SAVE_IMAGE(agent, argArray)
    imgName = getArg(argArray, "Name of saved image") 
    imgHost = getArg(argArray, "Image Host")
    disk = getArgDefault(argArray, "/dev/hda")
    
    cmd = "imagezip #{disk} - | curl -nsT - ftp://#{imgHost}/upload/#{imgName}"
    MObject.debug "AgentCommands", "Image save command: #{cmd}"
    ExecApp.new('builtin:save_image', agent, cmd, true)
  end

  #
  # Command 'RETRY'
  # 
  # Resend a command to the NH
  #
  # - agent = the instance of this NA
  # - argArray = an array with the sequence number of the commands to resend
  #
  def AgentCommands.RETRY(agent, argArray)
    # If this NA is operating with support for temporary disconnection, 
    # then ignore any RETRY requests from the NH.
    if agent.allowDisconnection?
      MObject.debug "Ignore RETRY (Disconnection Support ON)"
      return
    end
    first = getArg(argArray, "Id of first message to resend").to_i
    last = getArgDefault(argArray, -1).to_i
    if (last < 0)
      last = first
    end
    MObject.debug "AgentCommands", "RETRY message #{first}-#{last}"
    (first..last).each {|i|
      agent.communicator.resend(i)
    }
  end

  #
  # Command 'RALLO'
  #
  # Send a reliable ALLO message (used for testing)
  #
  # - agent = the instance of this NA
  # - argArray = an empty array 
  #
  def AgentCommands.RALLO(agent, argArray)
    agent.send(:ALLO, Time.now.strftime("%I:%M:%S"))
  end

  private

  # 
  # Remove the first element from 'argArray' and
  # return it. If it is nil, raise exception
  # with 'exepString' providing MObject.information about the
  # missing argument
  #
  # - argArray = Array of arguments
  # - exepString = MObject.information about argument, used for exception
  # 
  # [Return] First element in 'argArray' or raise exception if nil
  # [Raise] Exception if arg is nil
  #
  def AgentCommands.getArg(argArray, exepString)
    arg = argArray.delete_at(0)
    if (arg == nil)
      raise exepString
    end
    return arg
  end

  #
  # Remove the first element from 'argArray' and
  # return it. If it is nil, return 'default'
  #
  # - argArray = Array of arguments
  # - default = Default value if arg in argArray is nil
  #
  # [Return] First element in 'argArray' or 'default' if nil
  #
  def AgentCommands.getArgDefault(argArray, default = nil)
    arg = argArray.delete_at(0)
    if (arg == nil)
      arg = default
    end
    return arg
  end

end
