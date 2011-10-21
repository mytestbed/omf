source('../R/oml.R')

#r <- OML('srv.mytestbed.net:5053')$repo('demo-run-1')


#t <- r$table('rtt_roundtrip')$as('t')

#t$project(t['x']$as('x'))$where(t['x']$eq(1))$data()
#q <- t$project(t['sender']$as('s'), t['roundtrip']$as('rtt'))

o <- OML('127.0.0.1:5053')
t <- o$repo('ol_rtt')$table('rtt_roundtrip')
q <- t$project(t['oml_ts_server']$as('t'), t['addr'], t['roundtrip']$as('rtt'))

data = q$data()
#plot(data$t, data$rtt)
slice = data[data$rtt < 1, 'rtt']
plot(density(slice))
rug(slice)
