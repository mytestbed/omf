Dir["#{File.dirname(__FILE__)}/util/*.rb"].each do |file|
  require "omf_rc/resource_proxy/util/#{File.basename(file).gsub(/\.rb/, '')}"
end
