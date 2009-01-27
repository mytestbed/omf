require "rexml/document"
include REXML   # so that we don't have to prefix everything with REXML::...

file = File.new("mydoc.xml")  #Opens file with name "mydoc.xml"
doc = Document.new file
doc.elements.each("inventory/section"){|element| puts element.attributes["name"] }

doc.elements.each("*/section/item"){ |element| puts element.attributes["upc"] }

root = doc.root
puts root.attributes["title"]

puts root.elements["section/item[@stock='44']"].attributes["upc"]

puts root.elements["section"].attributes["name"]

puts root.elements[1].attributes["name"]

#root.detect {|root| node.kind_of? Element and node.attributes["name"] == "food" }

file.close()