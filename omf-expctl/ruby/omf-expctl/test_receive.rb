require "omf-common/omfPubSubService"

jid_suffix="10.0.1.200"

puts "TDEBUG - START PUBSUB - #{jid_suffix}"
# Set some internal attributes...
userjid = "10.0.1.1@#{jid_suffix}"
pubsubjid = "pubsub.#{jid_suffix}"
password = "123"

# Create a Service Helper to interact with the PubSub Server
begin
  @@service = OmfPubSubService.new(userjid, password, pubsubjid)
  # Start our Event Callback, which will process Events from
  # the nodes we will subscribe to
  #debug "TDEBUG - start 1"
  @@service.add_event_callback { |event|
    puts "TDEBUG - New Event - '#{event}'" 
  }
rescue Exception => ex
  error "ERROR - start - Creating ServiceHelper - PubSubServer: '#{pubsubjid}' - Error: '#{ex}'"
end

#debug "TDEBUG - start 2"
puts "Connected to PubSub Server: '#{pubsubjid}'"

@@service.leave_all_pubsub_nodes

sysNode = "/Domain/System/10.0.1.1"

while (!@@service.join_pubsub_node(sysNode))
  puts "CDEBUG - Node #{sysNode} does not exist (yet) on the PubSub server - retrying in 10s"
  sleep 10
end

sleep 100

@@service.quit