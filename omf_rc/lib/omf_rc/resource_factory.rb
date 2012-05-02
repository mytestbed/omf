require 'omf_common'
require 'securerandom'
require 'hashie'
require 'omf_rc/resource_proxy'

class OmfRc::ResourceFactory
  @@proxy_list = []
  @@utility_list = []

  class << self
    def new(type)
      raise ArgumentError, 'Type not found' unless @@proxy_list.include?(type)
      resource = OmfRc::ResourceProxy::AbstractResource.new(type)
      resource.extend("OmfRc::ResourceProxy::#{type.camelcase}".constant)
      resource
    end

    def proxy_list
      @@proxy_list
    end

    def register_proxy(proxy)
      @@proxies << proxy
    end
  end
end
