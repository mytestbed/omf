#
# THIS IS FOR WINLAB ONLY
#
# To use the old OMF 5.2 syntax for node description (e.g. [x,y])
# - load this file in your experiment
# - rename your 'defGroup' in your experiment by 'defGroup52'
# For example:
#    defGroup52('group1', [2,3]) 
#    defGroup52('group2', [[2,3],[4,5],[6,7]]) 
#    defGroup52('group3', [1..2,4..5]) 
#    defGroup52('group4', [[1..2,4..5],[6,7],[8,9]]) 
#    defProperty('res', [1..2,1..2], "Some nodes")
#    defGroup52('group5', property.res)
#    defGroup52('group6', ['group1','group2'])
#


# THIS IS FOR WINLAB ONLY
# Return a HRN for a resource based on:
# - its [x,y] coordinates
# - the testbed console on which this experiment is currently being executed
# - a fixed PREFIX
# e.g. if console's hostname is 'console.grid.orbit-lab.org' and prefix is 'node'
#      and the resource is at coordinate [1,2]
#      then the returned HRN is 'node1-2.grid.orbit-lab.org'
# 
HRN_PREFIX='node'
@@hrnSuffix = nil
def hrn(x,y)
  @@hrnSuffix = `hostname`.chomp!.split('console')[1] if @@hrnSuffix.nil?
  raise "Translating 5.2 resource syntax to 5.3 one. "+
        "Cannot figure out which WINLAB console we are running on! " +
        "(hostname: #{`hostname`})" if @@hrnSuffix.nil?
  return "#{HRN_PREFIX}#{x}-#{y}#{@@hrnSuffix}"
end

# THIS IS FOR WINLAB ONLY
# Turns a list of node in the 5.2 [x,y] syntax into a list of 5.3 HRN 
# (this code is from the 5.2. Topology class)
#
def turn_52_to_53(nodes)
    list = []
    if ! nodes[0].kind_of?(Array)
      # Array should contain two ranges
      return [] if nodes.length != 2
      x = nodes[0]
      if x.kind_of?(Integer)
        x = [x]
      elsif x.kind_of?(ExperimentProperty)
        x = [x.value]
      end
      y = nodes[1]
      if y.kind_of?(Integer)
        y = [y]
      elsif y.kind_of?(ExperimentProperty)
        y = [y.value]
      end
      # Expected two range declarations, but found #{nodes.join(', ')}."
      return [] if ! ((x.kind_of?(Range) || x.kind_of?(Array)) && (y.kind_of?(Array) || y.kind_of?(Range)))
      x.each { |i| y.each {|j| list << hrn(i, j) } }
    else
      nodes.each {|n| list << turn_52_to_53(n) }
    end
    return list
end

# THIS IS FOR WINLAB ONLY
# Provide a new 'defGroup52' method which accept 5.3 node coordinate syntax,
# turns them into 5.3 HRN syntax and call the 5.3 defGroup with it 
#
def defGroup52(groupName, selector = nil, &block)
  resources = nil
  # Make sure we use the selector's value if it's an Experiment Property
  selector = selector.value if selector.kind_of?(ExperimentProperty)
  # If this is a 5.2 selector then turn it into a 5.3 one
  if selector.kind_of?(Array)
    # Add a single resource
    if (selector.length == 2 && selector[0].kind_of?(Integer) && selector[1].kind_of?(Integer))
      resources = [hrn(selector[0],selector[1])]
    # Add a many resource
    else
      resources = turn_52_to_53(selector)
    end
  end
  # If the 5.2 to 5.3 process did not succeed, then use the original selector
  sel = (!resources.nil? && !resources.empty?) ? resources.join(',') : selector
  # Now call the 5.3 defGroup
  #puts ">>> s: '#{selector}'" ;  puts ">>> r: '#{sel}'"
  OMF::ExperimentController::CmdContext.instance.defGroup(groupName, sel, &block)
end

#
# Testing
#
#defGroup52('group1', [2,3]) 
#defGroup52('group2', [[2,3],[4,5],[6,7]]) 
#defGroup52('group3', [1..2,4..5]) 
#defGroup52('group4', [[1..2,4..5],[6,7],[8,9]]) 
#defProperty('res', [1..2,1..2], "Some nodes")
#defGroup52('group5', property.res)
#defGroup52('group6', ['group1','group2'])
#Experiment.done
