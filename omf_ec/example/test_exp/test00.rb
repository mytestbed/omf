# We can use communicator to interact with XMPP server
#
# Find all top level pubsub nodes
host = "pubsub.#{OmfCommon.comm.jid.domain}"

def discover
  OmfCommon.comm.discover('items', host, '') do |m|
    m.items.each { |i| info i.node }
    info "Found #{m.items.size} items"
  end
end


def cleanup
  OmfCommon.comm.affiliations do |a|
    if a[:owner]
      info "Found #{a[:owner].size} owned topics"
      info "Now cleaning up..."
      a[:owner].each do |t|
        OmfCommon.comm.delete_topic(t) do |m|
          debug m
        end
      end
    else
      info "Found no owned topics"
    end
  end
end

cleanup

done!
