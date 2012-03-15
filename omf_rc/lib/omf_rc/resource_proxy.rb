Dir["#{File.dirname(__FILE__)}/resource_proxy/*.rb"].each do |file|
  require "#{file.gsub(/\.rb/, '')}"
end
