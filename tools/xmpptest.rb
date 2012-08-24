#!/usr/bin/ruby

# change this to the gembundler path later
require "xmpp4r"
require "xmpp4r/pubsub"
require "socket"
include Jabber
#Jabber::debug = true

def quit(msg)
  puts msg
  exit 1
end

if ARGV.empty?
  quit("Please provide the hostname of the XMPP server as the command line argument.")
end

host = ARGV[0]

puts "-> Checking hostname"
begin
  Socket.gethostbyname(host)
rescue
  quit("Could not resolve XMPP host '#{host}'")
end

puts "-> Checking 'pubsub' subdomain of the hostname"
begin
  Socket.gethostbyname("pubsub.#{host}")
rescue
  puts "Could not resolve XMPP host 'pubsub.#{host}'. Server 2 Server connectivity may not work. Please create a DNS A or CNAME record for 'pubsub.#{host}' that points to the machine running the XMPP server."
end

# generate random user name and password
user = (0...8).map{65.+(rand(25)).chr}.join
pass = (0...8).map{65.+(rand(25)).chr}.join
jid = "#{user}@#{host}"
client = Client.new(jid) 

puts "-> Connecting to XMPP server"
begin
  client.connect(host)
rescue
  quit("Failed to connect to XMPP server. Is it listening on port TCP 5222 of '#{host}'?")
end

puts "-> Registering XMPP user"
begin
  client.register(pass)
rescue
  quit("Failed to register XMPP user. Ensure your XMPP server configuration allows in-band user registration")
end

puts "-> Authenticating XMPP user"
begin
  client.auth(pass)
rescue
  quit("Failed to authenticate XMPP user. Registration probably failed. Check the server logs and configuration.")
end

puts "-> Creating pubsub service helper"
begin
  pubsub = PubSub::ServiceHelper.new(client, host)
rescue
  quit("Failed to create pubsub service helper. Check if your XMPP server is configured for pubsub.")
end

puts "-> Creating pubsub node"
begin
  pubsub.create_node(user)
rescue
  quit("Failed to create pubsub node. Do the permissions of your XMPP server allow users to create pubsub nodes?")
end

puts "-> Publishing message to pubsub node"
begin
  item = Jabber::PubSub::Item.new
  xml = REXML::Element.new("test")
  xml.text = 'hello world!'
  item.add(xml);
  pubsub.publish_item_to(user, item)
rescue
  quit("Failed to publish pubsub message")
end

puts "-> Passed all tests. You should now be ready to use your XMPP server with OMF."
