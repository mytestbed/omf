Dir["#{File.dirname(__FILE__)}/resource_proxy/*.rb"].each do |file|
  require "omf_rc/resource_proxy/#{File.basename(file).gsub(/\.rb/, '')}"
end
