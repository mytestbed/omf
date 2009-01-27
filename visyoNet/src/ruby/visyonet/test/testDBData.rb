require "DBQM"


require "DBNode"
require "DBQueryManager"

#create a DBQueryManager object
qm = DBQueryManager.new

# set database connection parameters: host, username, password and database name
qm.setConnectionParameters("localhost", "nanyanj", "", "experiment")

# build query string
queryString="SELECT f.src_addr as nodeID, l.pos_x as posX, l.pos_y as posY, COUNT(src_addr) as nrPackets FROM frames f, locations l WHERE f.src_addr = l.addr GROUP BY nodeID"

# set the above query as the node query
qm.setNodeQuery(queryString)

# run the query 
result = qm.runNodeQuery()
# get the result set 
res = result.getResultSet()

# process the result of the query
puts "Number of packets originating from each node:"
printf "%d source nodes found:\n", res.num_rows 


node = DBNode.new

i = 0

while row = res.fetch_row do
	# print the first 2 fields
  #printf "nodeID: %s, pos: (%s, %s), nrPackets: %s\n", row[0], row[1], row[2], row[3]
  node.addNode(row[0], row[1], row[2], "nrPackets", row[3])
  #puts link.id
  puts node.id[i]
  #puts node.value[i]
  
  i = i + 1
end


# delete the result set after you are done
res.free



