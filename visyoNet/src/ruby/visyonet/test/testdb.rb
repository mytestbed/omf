require "DBQueryManager"

query="%t1% AND %t2% AND f2.dst_addr = f1.src_addr) AS loadIn          FROM frames f1, locations l".to_s
					
					s=10
e=20
query.gsub!("%t1%", "10")
puts query
