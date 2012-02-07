
require 'sqlite3'

db = SQLite3::Database.new("BrooklynDemo.sq3")

# find tables
tables = []
db.execute( "SELECT * FROM sqlite_master WHERE type='table';") do |r|
  table = r[1]
  tables << table unless table.start_with?('_')
end

tables.each do |t|
  puts "table: #{t}"
end

stmt = db.prepare( "select * from GPSlogger_gps_data" )
p stmt.columns
p stmt.types

#stmt.execute.each do |r| p r end
stmt.execute.each do |r|
  r.each do |c| p c.class end
  break
end

