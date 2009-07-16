require "omf-common/omfPubSubService"

@@service = nil

jid_suffix="10.0.0.200"

puts "TDEBUG - START PUBSUB - #{jid_suffix}"
# Set some internal attributes...
userjid = "aggmgr@#{jid_suffix}"
pubsubjid = "pubsub.#{jid_suffix}"
password = "123"

# Create a Service Helper to interact with the PubSub Server
begin
  @@service = OmfPubSubService.new(userjid, password, pubsubjid)
rescue Exception => ex
  puts "ERROR - start - Creating ServiceHelper - PubSubServer: '#{pubsubjid}' - Error: '#{ex}'"
end

#debug "TDEBUG - start 2"
puts "Connected to PubSub Server: '#{pubsubjid}'"

#@@service.leave_all_pubsub_nodes

sysNode = "/Domain/System/10.0.0.3"

#while (!@@service.join_pubsub_node(sysNode))
#  puts "CDEBUG - Node #{sysNode} does not exist (yet) on the PubSub server - retrying in 10s"
#  sleep 10
#end

  def send!(message, dst)                                                                           
    item = Jabber::PubSub::Item.new                                                                 
    msg = Jabber::Message.new(nil, message)                                                         
    item.add(msg)                                                                                   
    @@service.publish_to_node("#{dst}", item)                                                       
  end 


  send!("TEST","/Domain/System/10.0.0.3")
  
  @@service.quit