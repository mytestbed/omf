#
# Topology containing entire testbed
#

defTopology('system:topo:all'){ |t|
  all = OMF::Services.inventory.getListOfResources(OConfig.domain)
  all.elements.each("RESOURCES/NODE"){|e|
    t.addNode(e.text)
  }
}
