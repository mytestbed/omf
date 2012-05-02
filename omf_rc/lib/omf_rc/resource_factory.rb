require 'omf_common'
require 'securerandom'
require 'hashie'
require 'omf_rc/resource_proxy'
require 'omf_rc/resource_proxy/abstract_resource'

class OmfRc::ResourceFactory
  @@proxy_list = []
  @@utility_list = []

  class << self
    def new(type, opts = nil)
      raise ArgumentError, 'Type not found' unless @@proxy_list.include?(type)
      type = type.to_s
      resource = OmfRc::ResourceProxy::AbstractResource.new(type, opts)
      resource.extend("OmfRc::ResourceProxy::#{type.camelcase}".constant)
      resource
    end

    def proxy_list
      @@proxy_list
    end

    def register_proxy(proxy)
      @@proxy_list << proxy
    end

    def bootstrap
      Dir["#{File.dirname(__FILE__)}/resource_proxy/*.rb"].each do |file|
        require "omf_rc/resource_proxy/#{File.basename(file).gsub(/\.rb/, '')}"
      end
    end
  end
end
