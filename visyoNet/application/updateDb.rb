require "mysql"

# emulate with live database alone
# This module is started to update database with real time input
# Real time input is from another database only for demonstration purpose
# The data model should be able to catch the real time update
# start() is used to start the udpates
# pause() is used to pause the udpate
# stop() is used to exit real time update program
# Authored by Nanyan Jiang
# Dec. 2005


#database connection parameters: host, username, password and database name
dbh = Mysql.real_connect("localhost", "nanyanj", "", "experimentLive")
res1 = nil
res2 = nil
max_id = nil
id1 = 0
id2 = 0

# create new table to be used as updated table in the demonstration
createString="CREATE TABLE IF NOT EXISTS frames LIKE oldframes"
dbh.query(createString)

# build query string
count = 0


 
# clean 'newframes'
cleanString="TRUNCATE TABLE frames"
dbh.query(cleanString)

# The size of the 'newframes'
sizeOfTable = "SELECT max(id) FROM frames"
res2 = dbh.query(sizeOfTable)


t1 = 1
t2 = 10
# update 'newframes'

100.times do
	@updateString = "INSERT INTO frames SELECT * FROM oldframes f1 WHERE f1.id BETWEEN %t1% AND %t1%+9"
	#puts @updateString
	#puts t1.to_s
	query = @updateString.gsub("%t1%", t1.to_s)
	puts query
	t1=t1+10
	res1 = dbh.query(query)
	sleep(2)
end

#while row = res1.fetch_row do
#	printf "%s, %s\n", row[0], row[1]
#end
#printf "%d rows were returned\n", res1.num_rows

res1.free

dbh.close

# start update 
# parameter
def startUpdate()

end

def pauseUpdate()

end

def stopUpdate()

end



