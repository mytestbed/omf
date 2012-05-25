require 'omf_common'
require 'securerandom'
require 'hashie'
require 'omf_rc/resource_proxy_dsl'
require 'omf_rc/resource_proxy/abstract_resource'

class OmfRc::ResourceFactory
  @@proxy_list = []
  @@utility_list = []

  DEFAULT_OPTS = {
    dsl: 'xmpp_blather',
    pubsub_host: 'pubsub'
  }

  class << self
    def new(type, opts = nil, comm = nil, &block)
      raise ArgumentError, "Resource type not found: #{type.to_s}" unless @@proxy_list.include?(type)
      type = type.to_s
      opts = opts ? DEFAULT_OPTS.merge(opts) : DEFAULT_OPTS
      # Create a new instance of abstract resource
      resource = OmfRc::ResourceProxy::AbstractResource.new(type, opts, comm)
      # Then extend this instance with relevant module identified by type
      resource.extend("OmfRc::ResourceProxy::#{type.camelcase}".constant)
      # Execute resource before_ready hook if any
      resource.before_ready if resource.respond_to? :before_ready
      resource
    end

    def proxy_list
      @@proxy_list
    end

    def register_proxy(proxy)
      @@proxy_list << proxy
    end

    def utility_list
      @@utility_list
    end

    def register_utility(utility)
      @@utility_list << utility
    end

    def load_default_resource_proxies
      Dir["#{File.dirname(__FILE__)}/resource_proxy/*.rb"].each do |file|
        require "omf_rc/resource_proxy/#{File.basename(file).gsub(/\.rb/, '')}"
      end
    end

    def load_addtional_resource_proxies(folder)
      Dir["#{folder}/*.rb"].each do |file|
        require "#{folder}/#{File.basename(file).gsub(/\.rb/, '')}"
      end
    end
  end
end
