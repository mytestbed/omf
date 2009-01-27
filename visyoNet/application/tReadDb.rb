require "mysql"

# read new updated data from database
# using 
########
# Authored by Nanyan Jiang
# Dec. 2005

# database connection parameters: host, username, password and database name
dbh = Mysql.real_connect("localhost", "nanyanj", "", "experiment")
res = nil

# build query string
count = 0
interval = 1


5.times do
	sleep(1);
	queryString = "SELECT * FROM sensor";
	res = dbh.query(queryString);
	count+=1;
	puts "a "
end


res.each do |row|
       printf "%s, %s\n", row[0], row[1]
end
printf "%d rows were returned\n", res.num_rows

res.free

dbh.close


# SELECT @t1:=max(id) from frames;
# SELECT * FROM frames WHERE id = @t1;

