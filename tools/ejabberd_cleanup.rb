#!/usr/bin/ruby
require 'date'

# list of accounts that should not be removed
whitelist = ["aggmgr", "admin", "max", "zabbix"]
# XMPP server
server = 'norbit.npc.nicta.com.au'
# maximum user account age in days
maxage = 7

now = DateTime.now
registered = `ejabberdctl registered_users #{server}`.split("\n")
online = `ejabberdctl connected_users | awk '{split($0,a,"@#{server}"); print a[1]}'`.split("\n")

uid = %x[id -u $USER]
if uid.to_i != 0
  puts "You have to be root to run this."
  exit
end

# collect accounts with a timestamp less than 'maxage' days ago
not_expired = []
registered.each {|r|
  # look for a timestamp like this: 2010-07-19t13.31.24+10.00
  f = /\d{4}-\d{2}-\d{2}t\d{2}\.\d{2}\.\d{2}[+-]\d{2}\.\d{2}/.match(r)
  if f
    s = f[0]
    s.gsub('.',':').downcase
    if (now - DateTime.parse(s)).to_i < maxage
      not_expired << r
      puts "Account '#{r}' has been created less than #{maxage} days ago, keeping it."
    end
  end
}

delete = registered - online - not_expired - whitelist

if delete.empty?
  puts "Nothing to delete"
  exit
end

delete.each { |u|
  puts "Deleting Account #{u}"
  `ejabberdctl unregister #{u} #{server}`
}
