count=0
th = Thread.new { while true; sleep(10); print "a "; count+=1; end }
while count < 3 do end # no-op wait
th.critical = true
th.raise("Gotta")
puts "no more a's will come out." 	