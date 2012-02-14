#
# Topology containing entire active nodes on the current testbed
#
defTopology('system:topo:active') { |t|
  active = Topology["system:topo:active:#{OConfig.domain}"]
  active.each { |n|
    t.addNode(n)
  }
}
