#
# Topology containing entire grid
#

defTopology('system:topo:all', [1 .. (OConfig[:tb_config][:default][:x_max].to_i), 1 .. (OConfig[:tb_config][:default][:y_max].to_i)])
