# We can use communicator to interact with XMPP server
#
# Find all top level pubsub nodes
host = "pubsub.#{OmfCommon.comm.jid.domain}"

OmfCommon.comm.discover('items', host, '') do |m|
  m.items.each { |i| info i.node }
  info "Found #{m.items.size} items"
end

done!
