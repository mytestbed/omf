# We can use communicator to interact with XMPP server
#
# Find all top level pubsub nodes
host = "pubsub.#{OmfEc.comm.jid.domain}"

OmfEc.comm.discover('items', host, '') do |m|
  m.items.each { |i| info i.node }
  info "Found #{m.items.size} items"
end

done!

