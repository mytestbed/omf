# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'securerandom'
require 'hashie'
require 'omf_rc/resource_proxy_dsl'
require 'omf_rc/resource_proxy/abstract_resource'

# Factory class for managing available proxies and creating new resource proxy instances
#
class OmfRc::ResourceFactory
  include OmfRc::ResourceProxyDSL

  # List of registered resource proxies
  @@proxy_list = Hashie::Mash.new

  class << self
    # Factory method to initiate new resource proxy
    #
    # @param (see OmfRc::ResourceProxy::AbstractResource#initialize)
    #
    # @see OmfRc::ResourceProxy::AbstractResource
    def create(type, opts = {}, creation_opts = {}, &creation_callback)
      unless @@proxy_list.include?(type)
        raise ArgumentError, "Resource type not found: #{type.to_s}" unless @@proxy_list.include?(type)
      end
      # Get relevant module identified by type
      emodule = @@proxy_list[type].proxy_module || "OmfRc::ResourceProxy::#{type.camelize}".constantize
      # Create a new instance of abstract resource
      resource = OmfRc::ResourceProxy::AbstractResource.new(type, opts, creation_opts, &creation_callback)
      # Extend newly created resource with proxy module
      resource.extend(emodule)

      # Initiate property hash
      resource.methods.each do |m|
        resource.__send__(m) if m =~ /default_property_(.+)/
      end
      # Execute resource before_ready hook if any
      call_hook(:before_ready, resource)

      resource
    end

    alias :new :create

    # Return the proxy list
    def proxy_list
      @@proxy_list
    end

    # Add a proxy to the list
    def register_proxy(proxy_opts)
      if @@proxy_list.has_key? proxy_opts[:name]
        raise StandardError, "Resource has been registered already"
      else
        @@proxy_list.update(proxy_opts)
      end
    end

    # Require files from default resource proxy library folder
    def load_default_resource_proxies
      Dir["#{File.dirname(__FILE__)}/resource_proxy/*.rb"].each do |file|
        require "omf_rc/resource_proxy/#{File.basename(file).gsub(/\.rb/, '')}"
      end
    end

    # Require files from a folder contains resource proxy definition files
    #
    # @param [String] folder contains resource proxy definition files
    def load_additional_resource_proxies(folder)
      Dir["#{folder}/*.rb"].each do |file|
        require "#{folder}/#{File.basename(file).gsub(/\.rb/, '')}"
      end
    end
  end
end
