require "mysql"

# emulate with live database alone
# This module is started to update database with real time input
# Real time input is from another database only for demonstration purpose
# The data model should be able to catch the real time update
# start() is used to start the udpates
# pause() is used to pause the udpate
# stop() is used to exit real time update program
# Dec. 2005



#database connection parameters: host, username, password and database name
dbh = Mysql.real_connect("localhost", "nanyanj", "", "experiment")
res1 = nil
res2 = nil
max_id = nil
id1 = 0
id2 = 0

# The size of the 'frames'
sizeString = "SELECT MAX(id) FROM newframes"
res1 = dbh.query(sizeString)

while row = res1.fetch_row do
	max_id = row[0]
	printf "%s, %s\n", row[0], row[1]
end
printf "%d rows were returned\n", res1.num_rows

start = 0
20.times do
	sizeString = "SELECT MAX(id) FROM newframes"
	res1 = dbh.query(sizeString)

	while row = res1.fetch_row do	
		max_id = row[0]
		puts max_id
		#printf "%s, %s\n", row[0], row[1]
	end	
	
	@readString = "SELECT * FROM newframes WHERE id BETWEEN %t1% AND %t2% "
	queryString = @readString.gsub("%t1%", start.to_s).gsub("%t2%", max_id.to_s)
	#puts start.to_s
	start = max_id.to_s.to_i + 1
	#puts start.to_sS
	res2 = dbh.query(queryString)
	while row = res2.fetch_row do
	printf "%s, %s\n", row[0], row[1]
	end
	printf "%d rows were returned\n", res1.num_rows
	sleep(2)

end 

res1.free

dbh.close
