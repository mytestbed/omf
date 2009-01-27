require "mysql"

# emulate with live database alone
# This module is started to update database with real time input
# The data model should be able to catch the real time update
# start() is used to start the udpates
# pause() is used to pause the udpate
# stop() is used to exit real time update program
# authored by Nanyan Jiang
# Dec, 2005

#database connection parameters: host, username, password and database name
dbh = Mysql.real_connect("localhost", "nanyanj", "", "experiment")
res = nil

# build query string
count = 0
Thread.new{while true;
	sleep(2)
	insertString = "INSERT INTO sensor (temperature) VALUES ('89') "
	dbh.query(insertString)
	queryString = "SELECT * FROM sensor"
	res = dbh.query(queryString)
	deleteString = "DELETE FROM sensor WHERE temperature = '@i' "
	dbh.query(deleteString)
	count+=1
end
}

while count < 10
do end #no-op waits

res.each do |row|
       printf "%s, %s\n", row[0], row[1]
end
printf "%d rows were returned\n", res.num_rows

res.each_hash(with_table = true) do |row|
       printf "%s\n", row["sensor.temperature"]
end
printf "%d rows were returned\n", res.num_rows
   
res.free

dbh.close

# start update 
# parameter
def startUpdate()

end

def pauseUpdate()

end

def stopUpdate()

end





