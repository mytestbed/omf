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
require 'omf-resctl/omf_agent/nodeAgent'
require 'net/http'
require 'uri'

module AgentCommands

  @linkStates = Array.new

  OMF_MM_VERSION = OMF::Common::MM_VERSION()

  # For now we use these constant values for slave OMF entities.
  # We might want to have these config values passed as parameters later
  #
  # Slave Resource Controller 
  SLAVE_RC_CMD = "/usr/sbin/omf-resctl-#{OMF_MM_VERSION}"
  SLAVE_RC_CFG = "/etc/omf-resctl-#{OMF_MM_VERSION}/omf-resctl.local.yaml"
  SLAVE_RC_LOG = "/etc/omf-resctl-#{OMF_MM_VERSION}/omf-resctl.local.xml"
  # Slave Experiment Controller
  SLAVE_EC_CMD = "/usr/bin/omf-#{OMF_MM_VERSION} exec"
  SLAVE_EC_CFG = "/etc/omf-expctl-#{OMF_MM_VERSION}/omf-expctl.local.yaml"
  # Proxy OML Collection Server
  OML_PROXY_CMD = "/usr/bin/oml2-proxy-server"
  OML_PROXY_LISTENPORT = "9001"
  OML_PROXY_LISTENADDR = "localhost"
  OML_PROXY_CACHE = "/tmp/oml-proxy-cache"
  OML_PROXY_LOG = "/tmp/oml-proxy-log"
  
  # Mapping between OMF's device name and Linux's device name
  DEV_MAPPINGS = {
    'net/e0' => EthernetDevice.new('net/e0', 'eth0'),
    'net/e1' => EthernetDevice.new('net/e1', 'eth1'),
    #'net/w2' => AironetDevice.new('net/w2', 'eth2')
  }

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
  # Command 'ENROLL'
  # Initial enroll message received from the EC, to ask us to join an
  # Experiment
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.ENROLL(communicator, command)
    # Check if we are already 'enrolled' or not
    if controller.enrolled
      msg = "Resource Controller already enrolled! - "+
            "ignoring this ENROLL command!"
      MObject.debug("AgentCommands", msg)
      return {:success => :ERROR, :reason => :ALREADY_ENROLLED, :info => msg}
      #return
    end
    # Check if the desired image is installed on that node, 
    # if yes or if a desired image is not required, then continue
    # if not, then ignore this ENROLL
    communicator.set_EC_address
    desiredImage = command.image
    if (desiredImage != controller.imageName() && desiredImage != '*')
      msg = "Requested Image: '#{desiredImage}' - "+
            "Current Image: '#{controller.imageName()}'"
      MObject.debug("AgentCommands", msg)
      return {:success => :ERROR, :reason => :WRONG_IMAGE, :info => msg}
    end
    # Now instruct the communicator to listen for messages addressed to 
    # our new groups
    if !communicator.listen_to_experiment(command.expID) ||
       !communicator.listen_to_group(command.target)
      msg = "Failed to Process ENROLL command! "+
            "Maybe it came from an old experiment - ignoring it!"
      MObject.error("AgentCommands", msg)
      return {:success => :ERROR, :reason => :OLD_ENROLL, :info => msg}
    end
    # All is good, enroll this Resource Controller
    controller.enrolled = true
    controller.index = command.index 
    communicator.set_EC_address(command.ecaddress)
    msg = "Enrolled into Experiment ID: '#{command.expID}'"
    MObject.debug("AgentCommands", msg)
    return {:success => :OK, :reason => :ENROLLED, :info => msg}
  end

  #
  # Command 'ALIAS'
  # Set additional alias names for this RC
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.ALIAS(communicator, command)
    # Instruct the communicator to listen for messages addressed to 
    # our new group
    if !communicator.listen_to_group(command.name)
      msg = "Failed to Process ALIAS command! Cannot listen on the address "+
            "for this alias '#{command.name}'- ignoring it!"
      MObject.debug("AgentCommands", msg)
      return {:success => :ERROR, :reason => :WRONG_ALIAS, :info => msg}
      #communicator.send_error_reply("Failed to process ALIAS command"+
      #                        "Cannot listen on the ALIAS address", command) 
      #return
    end
    msg = "Enrolled into a new group: '#{command.name}'"
    MObject.debug("AgentCommands", msg)
    return {:success => :OK, :reason => :ENROLLED, :info => msg}
    #communicator.send_enrolled_reply(command.name)
  end

  #
  # Command 'EXECUTE'
  # Execute a program on the resource running this RC
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.EXECUTE(communicator, command)
    id = command.appID
    # Dump the XML description of the OML configuration into a file, if any
    useOML = false
    if (xmlDoc = command.omlConfig) != nil
      configPath = nil
      xmlDoc.each_element("omlc") { |omlc|
        configPath = "/tmp/#{omlc.attributes['exp_id']}-#{id}.xml"
      }
      f = File.new(configPath, "w+")
      xmlDoc.each_element {|el|
        f << el.to_s
      }
      useOML = true
      f.close
    end
    # Set the full command line and execute it
    cmdLine = ""
    cmdLine = cmdLine + "env -i #{command.env} " if command.env != nil
    cmdLine = cmdLine + "OML_CONFIG=#{configPath} " if useOML
    arguments = AgentCommands.substitute_values(controller, command.cmdLineArgs)
    cmdLine = cmdLine + "#{command.path} #{arguments}"
    MObject.debug "Executing: '#{cmdLine}'"
    ExecApp.new(id, controller, cmdLine)
  end

  def AgentCommands.substitute_values(controller, original)
    return if !original
    result = original
    # Get all the values to substitute
    allKey = original.scan(/%[0-9,a-z,.]*%/)
    # Perform substitutions
    allKey.each { |k|
      key = k[1..-1].chop
      value = nil
      case key
      when "index"
        value = controller.index
      when "hostname"
        value = `/bin/hostname`.chomp
      else
        # Check if this is a valid path
        if (type, id, prop = key.split(".")).length >= 3
          if (device = DEV_MAPPINGS["#{type}/#{id}"]) != nil
            value = device.get_property_value(prop.to_sym)
          end
        end 
      end
      result.gsub!("#{k}","#{value}") if value
    }
    return result 
  end


  #
  # Command 'KILL'
  # Send a signal to a process running on this resource
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.KILL(communicator, command)
    id = command.appID
    signal = command.value
    ExecApp[id].kill(signal)
  end

  #
  # Command 'EXIT'
  # Terminate an application running on this resource
  # First try to send the message 'exit' on the app's STDIN
  # If no succes, then send a Kill signal to the process
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.EXIT(communicator, command)
    id = command.appID
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
      msg = "Failed to terminate application: '#{id}' - Error: '#{err}'"
      MObject.debug("AgentCommands", msg)
      return {:success => :ERROR, :reason => :FAILED_EXIT, :info => msg}
      #communicator.send_error_reply(msg, command) 
    end
  end

  #
  # Command 'STDIN'
  # Send a line of text to the STDIN of a process
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.STDIN(communicator, command)
    begin
      id = command.appID
      line = command.value
      ExecApp[id].stdin(line)
    rescue Exception => err
      msg = "Error while writing to standard-IN of application '#{id}' "+
            "(cause: a call to 'sendMessage' or a dynamic property update)" 
      MObject.debug("AgentCommands", msg)
      return {:success => :ERROR, :reason => :FAILED_STDIN, :info => msg}
      #communicator.send_error_reply(msg, command) 
    end
  end

  #
  # Command 'PM_INSTALL'
  # Poor man's installer. Fetch a tar file and extract it into a 
  # specified directory
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.PM_INSTALL(communicator, command)
    id = command.appID
    url = command.image
    installRoot = command.path

    MObject.debug "Unpacking '#{url}' into '#{installRoot}'"
    
    file = "/#{File.basename(url)}"
    eTagFile = "#{file}.etag"
    download = true
    cmd = ""
    remoteETag = nil

    if file.empty?
      msg = "Failed to parse URL '#{url}'"
      MObject.debug("AgentCommands", msg)
      return {:success => :ERROR, :reason => :INVALID_URL, :info => msg}
    end
    
    # get the ETag from the HTTP header
    begin
      uri = URI.parse(url)
      res = Net::HTTP.start(uri.host, uri.port) {|http|
        header = http.request_head(url)
        remoteETag = header['etag']
      }      
    rescue Exception => err
      msg = "Failed to access URL '#{url}', error: '#{err}'"
      MObject.debug("AgentCommands", msg)
      return {:success => :ERROR, :reason => :DL_FAILED, :info => msg}
    end
    
    # if we have the file and its ETag locally, compare it to the ETag of the remote file
    if File.exists?(file) && File.exists?(eTagFile)
       f=File.open(eTagFile,'r')
       localETag=f.gets
       f.close
       if remoteETag == localETag
         download = false
       end
     end

    # download the file & store the ETag if necessary
    if download
      MObject.debug "Downloading '#{url}'"
      # -m -nd overwrites existing files
      cmd="wget -P / -m -nd -q #{url};"
      if !remoteETag.empty?
        f=File.open(eTagFile,'w')
        f.write remoteETag
        f.close
      end
     else
      MObject.debug "'#{file}' already exists and is identical to '#{url}', not downloading"
    end
    cmd += "tar -C #{installRoot} -xf #{file}"
    ExecApp.new(id, controller, cmd)
  end

  #
  # Command 'APT_INSTALL'
  # Execute apt-get command to install a package on this resource
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.APT_INSTALL(communicator, command)
    id = command.appID
    pkgName = command.package
    cmd = "LANGUAGE='C' LANG='C' LC_ALL='C' DEBIAN_FRONTEND='noninteractive' "+
          " apt-get install --reinstall --allow-unauthenticated -qq #{pkgName}"
    ExecApp.new(id, controller, cmd)
  end

  #
  # Command 'RPM_INSTALL'
  # Execute yum command to install a package on this resource
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.RPM_INSTALL(communicator, command)
    id = command.appID
    pkgName = command.package
    cmd = "/usr/bin/yum -y install #{pkgName}"
    ExecApp.new(id, controller, cmd)
  end

  #
  # Command 'RESET'
  # Reset this Resource Controller
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.RESET(communicator, command)
    controller.reset
  end

  #
  # Command 'RESTART'
  # Restart this Resource Controller
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.RESTART(communicator, command)
    communicator.stop
    ExecApp.killAll
    sleep 2
    system("/etc/init.d/omf-resctl-#{OMF_MM_VERSION} restart")
    # will be killed by now :(
  end

  #
  # Command 'REBOOT'
  # Reboot this resource... might not work on all the resources
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.REBOOT(communicator, command)
    communicator.stop
    sleep 2
    cmd = `sudo /sbin/reboot`
    if !$?.success?
      # In case 'sudo' is not installed but we do have root rights 
      # (e.g. PXE image)
      cmd = `/sbin/reboot`
    end
  end

  #
  # Command 'MODPROBE'
  # Load a kernel module on this resource
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.MODPROBE(communicator, command)
    moduleName = command.appID
    id = "module/#{moduleName}"
    ExecApp.new(id, controller, 
                "/sbin/modprobe #{argArray.join(' ')} #{moduleName}")
  end

  #
  # Command 'CONFIGURE'
  # Configure a system parameter on this resource
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.CONFIGURE(communicator, command)
    path = command.path
    value = AgentCommands.substitute_values(controller, command.value)
    result = Hash.new

    if (type, id, prop = path.split("/")).length >= 3
      if (device = DEV_MAPPINGS["#{type}/#{id}"]) != nil
        result = device.configure(prop, value)
      else
	result[:info] = "Unknown resource '#{type}/#{id}' in 'configure'"
      end
    else
      result[:info] = "Expected path '#{path}' to contain three levels"
    end
    MObject.debug("AgentCommands", result[:info])
    if !result[:success]
      result[:success] = :ERROR
      result[:reason] = :FAILED_CONFIGURE
    else      
      result[:success] = :OK
      result[:reason] = :CONFIGURED
    end
    return result
  end

  #
  # Command 'LOAD_IMAGE'
  # Load a specified disk image onto this resource 
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.LOAD_IMAGE(communicator, command)
    mcAddress = command.address
    mcPort = command.port
    disk = command.disk

    MObject.info("AgentCommands", "Image from ", mcAddress, ":", mcPort)
    ip = communicator.localAddr
    cmd = "frisbee -i #{ip} -m #{mcAddress} -p #{mcPort} #{disk}"
    MObject.debug("AgentCommands", "Frisbee command: ", cmd)
    ExecApp.new('builtin:load_image', controller, cmd, true)
  end

  #
  # Command 'SAVE_IMAGE'
  # Save the image of this resource and send it to the image server.
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.SAVE_IMAGE(communicator, command)
    imgHost = command.address
    imgPort = command.port
    disk = command.disk
    
    cmd = "imagezip -z1 #{disk} - | nc -q 0 #{imgHost} #{imgPort}"
    MObject.debug("AgentCommands", "Image save command: #{cmd}")
    ExecApp.new('builtin:save_image', controller, cmd, true)
  end

  def AgentCommands.NOOP(communicator, command)
    # Do Nothing...
  end

  #  Command 'SET_LINK'
  #
  #  Set the characteristics of a link using a specific emulation tool
  #
  # - communicator = the instance of this RC's communicator
  # - command = the command to execute
  #
  def AgentCommands.SET_LINK(communicator, command)
    # Check that we know the tool to use in order to set this link
    tool = command.emulationTool
    interface = command.interface
    setter = "set_link_#{tool}" if tool
    if !tool || !respond_to?(setter)
      return {:success => :ERROR, :reason => :UNKNOWN_EMULATION_TOOL, 
              :info => "Could not setup link characteristics with unknown "+
                       "emulation tool '#{tool}'"}
    end
    # Get the tool and use it to set the link
    cmdArray = method(setter).call(command)
    resultArray = Array.new
    success = false
    cmdArray.each { |cmd|
      resultArray << `#{cmd}` 
      if $?.success?
	success = true
	break
      end
    }
    # Process the result and reply
    if success
      @linkStates << {:interface => interface, :tool => tool}
      msg = "Set emulated link on interface '#{interface}' with '#{tool}'"
      result = {:success => :OK, :reason => :SET_LINK, :info => msg}
    else
      msg = "Could not set emulated link on interface '#{interface}' "+
            "with '#{tool}' and using commands '#{cmdArray.join(" --OR-- ")}'"+
	    " - The results are: '#{resultArray.join(" --AND-- ")}'"
      result =  {:success => :ERROR, :reason => :FAILED_SET_LINK, :info => msg}
    end
    MObject.debug("AgentCommands", msg)
    return result
  end

  def AgentCommands.reset_links
    @linkStates.each { |link|
      # Check that we know the tool to use in order to reset this link
      tool = link[:tool]
      iface = link[:interface]
      resetter = "reset_link_#{tool}" if tool
      if !tool || !respond_to?(resetter)
        MObject.debug("AgentCommands", "Cannot reset link on '#{iface}' with "+
                      "unknown tool '#{tool}'")
      end
      # Get the tool and use it to set the link
      cmd = method(resetter).call(iface)
      result = `#{cmd}` 
      # we don't care if it worked...
    }
  end

  def AgentCommands.set_link_iptable(options)
    cmd= "iptables -A INPUT -m mac --mac-source #{options.blockedMAC} -j DROP"
    return [cmd]
  end
  def AgentCommands.reset_link_iptable(interface)
    return "iptables -F ; iptables -X"
  end

  def AgentCommands.set_link_ebtable(options)
    cmd= "ebtables -A INPUT --source #{options.blockedMAC} -j DROP"
    return [cmd]
  end
  def AgentCommands.reset_link_ebtable(interface)
    return "ebtables -F ; ebtables -X"
  end

  def AgentCommands.set_link_mackill(options)
    cmd1 = "echo - #{options.blockedMAC} > /proc/net/mackill"
    cmd2 = "sudo chmod 666 /proc/net/mackill ; "+
           "sudo echo \"-#{options.blockedMAC}\">/proc/net/mackill"
    return [cmd1, cmd2]
  end
  def AgentCommands.reset_link_mackill(interface)
    return "echo '' >  /proc/net/mackill"
  end

  def AgentCommands.set_link_netem(options)
    iface = DEV_MAPPINGS["net/#{options.interface}"].deviceName
    pNetem = "netem "
    pNetem << "delay #{options.delay} " if options.delay
    pNetem << "#{options.delayVar} " if options.delayVar
    pNetem << "#{options.delayCor} " if options.delayCor
    pNetem << "loss #{options.loss} " if options.loss
    pNetem << "#{options.lossCor} " if options.lossCor
    pNetem << "corrupt #{per} " if options.per
    pNetem << "duplicate #{duplication} " if options.duplication

    # NOTE: someone much skilled in netem/tc should review this
    # to see if we can optimise it...
    # Case 1 - BW only 
    if options.bw && pNetem == "netem "      
      pTBF = "tbf rate #{options.bw} buffer #{options.bwBuffer} "+
             "limit #{options.bwLimit}"
      cmdRule = "tc class add dev #{iface} parent 1:1 "+
                "classid 1:1#{options.ruleID} htb rate 1000Mbps ; "+
                "tc qdisc add dev #{iface} "+
                "parent 1:1#{options.ruleID} handle #{options.ruleID}0: #{pTBF}"
      MObject.debug "TBF: '#{cmdRule}'"

    # Case 2 - BW and NETEM 
    elsif options.bw  && pNetem != "netem "  
      pTBF = "tbf rate #{options.bw} buffer #{options.bwBuffer} "+
             "limit #{options.bwLimit}"
      cmdRule = "tc class add dev #{iface} parent 1:1 "+
                "classid 1:1#{options.ruleID} htb rate 1000Mbps ; "+
                "tc qdisc add dev #{iface} parent 1:1#{options.ruleID} handle "+
                "#{options.ruleID}0: #{pNetem} ; "+
                "tc qdisc add dev #{iface} parent #{options.ruleID}0:1 "+
                "handle #{options.ruleID}0:1 #{pTBF}"
                #"handle #{options.ruleID}01: #{pTBF}"
      MObject.debug "TBF Netem: '#{cmdRule}'"

    # Case 2 - NETEM only
    elsif !options.bw && pNetem != "netem "  
      cmdRule = "tc class add dev #{iface} parent 1:1 "+
                "classid 1:1#{options.ruleID} htb rate 1000Mbps ; "+
                "tc qdisc add dev #{iface} "+
                "parent 1:1#{options.ruleID} handle #{options.ruleID}0: "+
                "#{pNetem}"
      MObject.debug "Netem: '#{cmdRule}'"
    end

    if options.portDst
      cmdFilter= "tc filter add dev #{iface} protocol ip parent 1:0 prio 3 "+
                 "u32 match ip protocol #{options.protocol} 0xff "+
                 "match ip dport #{options.portDst} 0x#{options.portRange} "+
                 "match ip dst #{options.targetIP} flowid 1:1#{options.ruleID}"
    else
      cmdFilter= "tc filter add dev #{iface} protocol ip "+
                 "parent 1:0 prio 3 u32 match ip dst #{options.targetIP} "+
                 "flowid 1:1#{options.ruleID}"
    end
    cmd1 = cmdRule + " ; " + cmdFilter
    # if cmd1 fail, try again but first set the interface in tc
    cmd2 = "tc qdisc add dev #{iface} handle 1: root htb" + " ; " + cmd1 
    return [cmd1, cmd2]
  end
  def AgentCommands.reset_link_netem(interface)
    iface = DEV_MAPPINGS["net/#{interface}"].deviceName
    return "tc qdisc del dev #{iface} root "
  end

  #
  # Command 'SET_DISCONNECTION'
  # 
  # Activate the 'Disconnection Mode' for this RC. 
  # In this mode, this RC will be a 'master' RC, which will execute a 
  # proxy OML server, a 'slave' RC and a 'slave' EC. It will instruct the
  # 'slave' EC to execute the experiment parts related to this resource. It 
  # will monitor this EC, and upon its termination, it will notify the OML 
  # proxy to forward the measurements back to the main OML server. 
  #
  def AgentCommands.SET_DISCONNECTION(communicator, command)
    controller.allowDisconnection = true
    communicator.allow_retry
    MObject.debug("AgentCommands", "Disconnection Support Enabled")
    
    # Retrieve original experiment parameters from the command
    omlAddr = command.omlURL.split(":")[1]
    omlPort = command.omlURL.split(":")[2]
    expPath = "/tmp/#{command.expID}-ED.rb" 
    expFile = File.new(expPath, "w+")
    expFile << command.exp
    expFile.close
    MObject.debug("AgentCommands", "Original Experiment Description saved at "+
                  "'#{expPath}'")

    # Now Start a Proxy OML Server
    cmd = "#{OML_PROXY_CMD} --listen #{OML_PROXY_LISTENPORT} \
                            --dstaddress #{omlAddr}\
                            --dstport #{omlPort} \
                            --resultfile #{OML_PROXY_CACHE} \
                            --logfile #{OML_PROXY_LOG}"
    MObject.debug("Starting OML Proxy Server with: '#{cmd}'")
    ExecApp.new(:OML_PROXY, controller, cmd)

    # Now Start a Slave RC 
    cmd = "#{SLAVE_RC_CMD} -C #{SLAVE_RC_CFG} --log #{SLAVE_RC_LOG} \
                           --name #{controller.agentName} \
                           --slice #{controller.agentSlice}" 
    MObject.debug("Starting Slave RC with: '#{cmd}'")
    ExecApp.new(:SLAVE_RC, controller, cmd)
    
    # Now Start a Slave EC
    cmd = "#{SLAVE_EC_CMD} -C #{SLAVE_EC_CFG} --slice #{controller.agentSlice} \
                           --slave-mode #{command.expID} \
                           --slave-mode-omlport #{OML_PROXY_LISTENPORT} \
                           --slave-mode-omladdr #{OML_PROXY_LISTENADDR} \
                           --slave-mode-resource #{controller.agentName} \
                           #{expPath}"
    MObject.debug("Starting Slave EC with: '#{cmd}'")
    ExecApp.new(:SLAVE_EC, controller, cmd)

    # Tell the Master EC that from now on we can be disconnected
    return {:success => :OK, :reason => :DISCONNECT_READY}
  end

end


  #
  # This used to be in the devel code on netem
  # However, OMF 5.3 does not have any clean support for dynamically updating
  # topologies during an experiment execution. Moreover, doing such thing 
  # (dynamically updating topologies) is not used by IREEL, which is the main
  # user of Link Emulation in OMF. 
  # Thus, we decided to push the integration of this to OMF 5.4
  # We keep that code around here, as it may be useful for 5.4 devel
  #
  # Command 'REMOVE_TRAFFICRULES'
  #
  # Remove a traffic rule and the filter attached. It not destroys the main 
  # class which hosts the rule
  # - values = values needed to delete a rule an a filter : the Id, and all 
  # parameters of the filter
  #
#  def AgentCommands.REMOVE_TRAFFICRULES(agent , argArray)
#    #check if the tool is available (Currently, only TC)
#    if (!File.exist?("/sbin/tc"))
#      raise "Traffic shaping method not available in 'SET_TRAFFICRULES'"
#    else
#      ipDst= getArg(argArray, "value of the destination IP")
#      portDst=getArg(argArray, "value of the port for filter based on port")
#      portRange=getArg(argArray, "Range for filtering by port")
#      nbRules = getArg(argArray , "Number of rules")
#      portRange = portRange.to_i
#      portRange = 65535 - portRange
#      portRange = portRange.to_s(16)
#      #Rule deletion.
#      cmdDelRule ="tc qdisc del dev eth0 parent 1:1#{nbRules} handle #{nbRules}0: ; tc qdisc add dev eth0 parent #{nbRules}0:1 handle #{nbRules}01: "
#      MObject.debug "Exec: '#{cmdDelRule}'"
#      result=`#{cmdDelRule}`
#      #Filter deletion
#      if(portDst!="-1")
#        cmdFilter= "tc filter del dev eth0 protocol ip parent 1:0 prio 3 u32 match ip protocol 17 0xff match ip dport #{portDst} 0x#{portRange} match ip dst #{ipDst} flowid 1:1#{nbRules}"
#      else
#        cmdFilter= " tc filter del dev eth0 protocol ip parent 1:0 prio 3 u32 match ip dst #{ipDst} flowid 1:1#{nbRules}"
#      end
#      MObject.debug "Exec: '#{cmdFilter}'"
#      result=`#{cmdFilter}`
#    end
#  end
