#
# Topology containing entire active nodes on the current testbed
#
defTopology('system:topo:active') { |t|
  active = Topology["system:topo:active:#{OConfig.GRID_NAME}"]
  active.eachNode { |n|
    t.addNode(n.x , n.y)
  }
}
