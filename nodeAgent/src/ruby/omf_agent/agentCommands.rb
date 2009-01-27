#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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

require 'util/mobject'
require 'util/execApp'
#require 'omf_driver/aironet'
require 'omf_driver/ethernet'

module AgentCommands

  # Version of the communication protocol between the NH and the NAs
  PROTOCOL_VERSION = "4.2"

  # Mapping between OMF's device name and Linux's device name
  DEV_MAPPINGS = {
    'net/e0' => EthernetDevice.new('net/e0', 'eth0'),
    #'net/w2' => AironetDevice.new('net/w2', 'eth2')
  }

  # Code Version of this NA
  VERSION = "$Revision: 1273 $".split(":")[1].chomp("$").strip
  SYSTEM_ID = :system

  # File containing image name
  IMAGE_NAME_FILE = '/.orbit_image'

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
    agentId = getArg(argArray, "Name of agent")
    ignoreMsg = getIntArg(argArray, "Highest seq# to ignore")

    agent.addAlias(agentId, true)
    agent.communicator.ignoreUpTo(ignoreMsg)
    argArray.each{ |name|
      agent.addAlias(name)
    }
    agent.okReply(:YOUARE)
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
        if (! system("wget -q -O #{fileName} #{url}"))
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
    id = getArg(argArray, "ID of process")
    line = argArray.join(' ')
    ExecApp[id].stdin(line)
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
    cmd = "cd /tmp;wget -q #{url};"
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
    ExecApp.killAll
    system('/etc/init.d/nodeAgent restart')
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
    cmd = `sudo /sbin/reboot`
    if !$?.success?
      # In case 'sudo' is not installed but we do have root rights (e.g. PXE image)
      cmd = `/sbin/reboot`
    end
    #system('/sbin/reboot')
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
    value = getArg(argArray, "Value to set parameter to")

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
  # - argArray = an array with the path to the file server, the image name, and the name of the disk device to save
  #
  def AgentCommands.SAVE_IMAGE(agent, argArray)
    nsfDir = getArg(argArray, "NSF path for saved image")
    imgName = getArg(argArray, "Name of saved image")
    disk = getArgDefault(argArray, "/dev/hda")

    MObject.info "AgentCommands", "Image zip #{disk} to #{nsfDir}/#{imgName}"
    if ! system("mkdir /mnt")
      MObject.info("WARNING - While creating directory /mnt - '#{$?}'")
    end
    # Dir.mkdir("/mnt")
    #check the disk.  Assuming that the system disk is hda1
    # cmd = "fsck -py #{disk}1"
    # if ! system(cmd)
    # raise "While fscking #{$?}"
    # end
    if ! system("mkdir /mount")
      MObject.info("WARNING - While creating directory /mount - '#{$?}'")
    end
    system("mount #{disk}1 /mount")
    File.open("/mount/#{IMAGE_NAME_FILE}", 'w') {|f| f.puts(imgName)}
    system("umount /mount")
    cmd = "mount -o nolock #{nsfDir} /mnt"
    if ! system(cmd)
      raise "While mounting #{nsfDir}: #{$?}"
    end

    cmd = "imagezip #{disk} /mnt/#{imgName}"
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
    first = getArg(argArray, "Id of first message to resend").to_i
    last = getArgDefault(argArray, -1).to_i
    if (last < 0)
      last = first
    end
    MObject.debug "AgentCommands", "RETRY message #{first}-#{last}"
    (first..last).each {|i|
      agent.resend(i)
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

  #
  # Remove the first element from 'argArray' and
  # return it. If it is not an Integer, raise exception
  # with 'exepString' providing MObject.information about the
  # missing argument
  #
  # - argArray = Array of arguments
  # - exepString = MObject.information about argument, used for exception
  #
  # [Return] First element in 'argArray' as integer
  # [Raise] Exception if arg is not an integer
  #
  def AgentCommands.getIntArg(argArray, exepString)
    sarg = getArg(argArray, exepString)
    arg = sarg.to_i
    if (arg.to_s != sarg)
      raise exepString
    end
    return arg
  end

end
