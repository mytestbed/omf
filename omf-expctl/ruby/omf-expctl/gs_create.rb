require "omf-common/omfPubSubService"

jid_suffix="10.0.1.200"

puts "TDEBUG - START PUBSUB - #{jid_suffix}"
# Set some internal attributes...
userjid = "aggmgr@#{jid_suffix}"
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
    execute_command(event)
    puts "TDEBUG - Finished Processing Event" 
  }         
rescue Exception => ex
  error "ERROR - start - Creating ServiceHelper - PubSubServer: '#{pubsubjid}' - Error: '#{ex}'"
end

#debug "TDEBUG - start 2"
puts "Connected to PubSub Server: '#{pubsubjid}'"
    
# let the gridservice do this:
@@service.create_pubsub_node("/Domain")
@@service.create_pubsub_node("/Domain/System")
@@service.create_pubsub_node("/Domain/System/10.0.1.1")
@@service.create_pubsub_node("/Domain/System/10.0.1.2")
@@service.create_pubsub_node("/Domain/System/10.0.1.3")
@@service.create_pubsub_node("/Domain/System/10.0.1.4")


