

require 'omf-oml/table'

# A simple table holding animal population 
#

table = OMF::OML::OmlTable.new :animals, [:name, [:count, :int]]
table.add_row ['mouse', 1]
table.add_row ['cat', 2]
table.add_row ['dog', 3]

require 'omf_web'
OMF::Web.register_datasource table
