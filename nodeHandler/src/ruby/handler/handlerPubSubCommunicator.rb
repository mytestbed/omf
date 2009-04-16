#
#  IMPORTANT TODO: 
#
#  This file is most probably broken!
#  This is the first version of PubSub communicator attempted by Javid... it is not working!
#  
#  This code needs to be changed/revised based on the model of 'agentPubSubCommunicator' in the
#  Node Agent source tree.
#
#


# This file is to implement a srvice helper for OMF Pubsub NH
# This service uses NorbitPubdubServiceHelper


module Jabber
  module PubSub
    class NodeHandlerPubSubCommunicator < MObject
    
      include Singleton
      @@instantiated = false
    
      def NodeHandlerPubSubCommunicator.instantiated?
        return @@instantiated
      end    
    
      #
      # Creates a new NodeHandler
      def initialize ()
        @name2node = Hash.new
        @@instantiated = true
        #@@nodehandlernode=""
        @handlerCommands = Hash.new        
      end
      
      #
      # Configure and Start a NodeHandler to be at a specific hierarchy location
      # specified by its current ExperimentID
      # exmaple = start("/Domain/Session/SID/EXP","user1@npc.nicta.com.au","123","pubsub.npc.nicta.com.au")
      # - expid = [string] experiment ID
      # - userjid = [string], username in a XMPP server (like openfire)
      # - password = [string], password
      # - pubsubjid = [string], pubsubjid address in a XMPP server
      def start(expid,userjid,password,pubsubjid)
        @expid=expid
        connect_to_server(userjid,password,pubsubjid)
        
        #xx=Time.new
        #yy=xx.to_s.gsub(' ','-')
        #@@nodehandlernode=@expid+"/"+yy
        #@service.create_pubsub_node(@@nodehandlernode)
        
        bootstrap       
      end
      
      #
      # Send a message to a group of nodes or a unique NA
      # It checks if a PubSub node with the name "targer" exists
      # in experiment or system nodes. If it does, it will send 
      # the command to that node, otherwise does nothing.
      # - targer = [string], name of a pubsub node
      # - command = [string], the command to be sent
      # - msgArray = [string], array of arguments attached to a command to be sent
      def send(targer,command,msgArray)
        msg = "S #{target} #{command} #{LineSerializer.to_s(msgArray)}"
        debug("Send message: ", msg)      
      
        cmd=command+' '+msgArray*' '

        if (send_command_to_agents(cmd,"/"+targer)==false)
          send_command_to_macID(cmd,"/"+targer)
        end
      
      end
      
      #
      # Send a Reset command to all nodes of the experiment
      def sendReset
        xx=@expid.split('/')
        xx.pop
        node=xx*'/'
        
        send_command_to_agents("R",node)
      end
      
      #
      # This method enrolls 'node' with 'macID' and 'name'
      # When this node checks in, it will automatically
      # get 'name' assigned.
      # - node = [string], node
      # - name = [string], name assinged to the node
      # - macID = [string], macID of the agent that is supposed to receive this command
      def enrollNode(node, name, macID)
        @name2node[name] = node
        send_command_to_macID("JOIN /#{node}",macID)
      end
      
      #
      # This method removes a node from the Communicator's list of 'alive' nodes.
      # When a given 'Node' object is being removed from all the existing 
      # topologies, it calls this method to notify the Communicator, so 
      # subsequent messages received from the real physical node will be 
      # discarded by the Commnunicator in the processCommand() call.
      # Furthermore, 'X' command is sent to the commServer to remove all
      # group associated to this node at the commServer level. Finally, a
      # 'RESET' command is sent to the real node.
      # - name = [string], name of the node
      def removeNode(name)
        @name2node[name] = nil
        
        send(name,"RESET","")
      end    
      
      #
      # This method adds a node to an additional group
      # - node = [string], macID of the agent that is supposed to join a group
      def addToGroup(node,groupName)
        send(node,"JOIN /#{groupName}","")
      end
      
      #
      def quit()
        sendReset
      end
      
      #
      # Connect the NodeHanlder to a XMPP server using a current user
      # exmaple: connect_to_server("user1@npc.nicta.com.au","123","pubsub.npc.nicta.com.au")
      # - userjid = [string], username in a XMPP server (like openfire)
      # - password = [string], password
      # - pubsubjid = [string], pubsubjid address in a XMPP server
      def connect_to_server(userjid,password,pubsubjid)
        @client=Client.new(userjid)
        @client.connect
        @client.auth(password)
        @client.send(Presence.new)
        
        @pubsubjid=pubsubjid
        @service=NorbitPubSubServiceHelper.new(@client,@pubsubjid)
      end
      
      #
      # Runs the bootstap for a NodeHandler
      def bootstrap
        @service.add_event_callback { |event|
          execute_command(event)
        }        
      end   

      #
      # Create a Group inside the current Experiment
      # - expname = [string], name of the group to be created
      def create_group (expname)
        expnode=@expid+"/"+expname
        @service.create_pubsub_node(expnode)
      end
      
      #
      # Delete all nodes a NodeHanlder owns
      def delete_all_nodes
        list=get_affiliations
        list.each {|key,value|
          if (value==:owner)
            puts key
            @service.delete_node(key)
          end
         }
      end

      
      #
      # Sends a command to a pubsub node inside the current Experiment
      # exmaple: send_command_to_agents("JOIN /Grp2","/Grp1")
      # - cmd = [string], command
      # - address = [string], address of a group 
      # [Return] true/false       
      def send_command_to_agents(cmd,address)
        node=@expid+address
        
        flag=false
        if (node_type?(node)!="")
          send_command_to_node(cmd,node)
          flag=true
        end
        flag
      end
      
      #
      # Sends a command to a macID node inside the current Domain
      # exmaple: send_command_to_macID("JOIN /Grp2","/MacID-0")
      # - cmd = [string], command
      # - macID = [string], macID of the agent
      # [Return] true/false       
      def send_command_to_macID(cmd,macID)
        xx=@expid.split('/')
        domain=xx[1]
        node="/"+domain+"/System"+macID
        
        flag=false
        if (node_type?(node)!="")
          send_command_to_node(cmd,node)
          flag=true
        end
        
        flag
      end
      
      #
      # Sends a command to a pubsub node
      # exmaple: send_command_to_node("JOIN /Exp1/Grp2","/Domain/Session/expid/Exp1/Grp1")
      # - cmd = [string], command
      # - node = [string], a pubsub node that is supposed to receive this command      
      def send_command_to_node(cmd,node)
        item = Jabber::PubSub::Item.new
        message=Jabber::Message.new(nil,cmd)
        item.add(message)
        @service.publish_to_node(node,item)
      end
      

      #
      # This method processes the command comming from an agent
      # @param argArray command line parsed into an array
      # - argArray = array of a command and its arguments
      def processCommand(argArray)
        debug "Process message '#{argArray.join(' ')}'"
        if argArray.size < 2
          raise "Command is too short '#{argArray.join(' ')}'"
        end
        senderId = argArray.delete_at(0)
        sender = @name2node[senderId]
      
        if (sender == nil)
          debug "Received message from unknown sender '#{senderId}': '#{argArray.join(' ')}'"
          return
        end
        
        command = argArray.delete_at(0)
        # First lookup this comand within the list of handler's Commands
        method = @handlerCommands[command]
        # Then, if it's not a handler's command, lookup it up in the list of agent's commands
        if (method == nil)
          begin
            method = @handlerCommands[command] = AgentCommands.method(command)
          rescue Exception
            warn "Unknown command '#{command}' received from '#{senderId}'"
            return
          end
        end
  
        begin
        # Execute the command
          reply = method.call(self, sender, senderId, argArray)
        rescue Exception => ex
        #error("Error ('#{ex}') - While processing agent command '#{argArray.join(' ')}'")
          debug("Error ('#{ex}') - While processing agent command '#{argArray.join(' ')}'")
        end
      end      
      
      
      #
      # Execute a command received by a NodeHandler. This is the callback function
      # to be invoked everytime the NH recevies an event from the XMPP server
      # - event = An XML event sent by the XMPP server
      def execute_command (event)
        eventName=event.first_element("items").first_element("item").first_element("message").first_element("body").text
        eventName = eventName.to_s.upcase
        # args=cmd.split(' ')

        debug "Received --> #{args[0]} #{args[1]}"
        
        if (msg != nil && eventName == "STDOUT" && msg[0] == ?#)
          ma = msg.slice(1..-1).strip.split
          cmd = ma.shift
          msg = ma.join(' ')
          if cmd == 'WARN'
            MObject.warn('commServer', msg)
          elsif cmd == 'ERROR'
            MObject.error('commServer', msg)
          else
            MObject.debug('commServer', msg)
          end
          return
        end
        
        debug("commServer(#{eventName}): '#{msg}'")
        if (eventName == "STDOUT")
          a = LineSerializer.to_a(msg)
          processCommand(a)
        elsif (eventName == "DONE.ERROR")
          error("ComServer failed: ", msg)\
        end
      end
      
    end #class
  end #module
end #module
