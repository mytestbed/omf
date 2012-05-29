# DSL contains some helper methods to ease the process defining resource proxies
#
module OmfRc::ResourceProxyDSL
  PROXY_DIR = "omf_rc/resource_proxy"
  UTIL_DIR = "omf_rc/util"

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Register a named proxy entry with factory class, normally this should be done in the proxy module
    #
    # @param [Symbol] name of the resource proxy
    # @example suppose we define a module for wifi
    #
    #   module OmfRc::ResourceProxy::Wifi
    #     include OmfRc::ResourceProxyDSL
    #
    #     # Let the factory know it is available
    #     register_proxy :wifi
    #   end
    #
    def register_proxy(name)
      name = name.to_sym
      OmfRc::ResourceFactory.register_proxy(name)
    end

    # Register some hooks which can be called at certain stage of the operation
    #
    # Currently the system supports two hooks:
    #
    # * before_ready, called when a resource created, before creating an associated pubsub node
    # * before_release, called before a resource released
    #
    # @param [Symbol] name hook name. :before_create or :before_release
    # @yieldparam [AbstractResource] resource pass the current resource object to the block
    # @example
    #
    #   module OmfRc::ResourceProxy::Node
    #    include OmfRc::ResourceProxyDSL
    #
    #    register_proxy :node
    #
    #    register_hook :before_ready do |resource|
    #      logger.info "#{resource.uid} is now ready"
    #    end
    #
    #    register_hook :before_release do |resource|
    #      logger.info "#{resource.uid} is now released"
    #    end
    #   end
    def register_hook(name, &register_block)
      define_method(name) do
        register_block.call(self) if register_block
      end
    end

    # Include the utility by providing a name
    #
    # The utility file can be added to the default utility directory UTIL_DIR, or defined inline.
    #
    # @param [Symbol] name of the utility
    # @example assume we have a module called iw.rb in the omf_rc/util directory, providing a module named OmfRc::Util::Iw with functionalities based on iw cli
    #
    #   module OmfRc::ResourceProxy::Wifi
    #     include OmfRc::ResourceProxyDSL
    #
    #     # Simply include this util module
    #     utility :iw
    #   end
    def utility(name)
      name = name.to_s
      begin
        # In case of module defined inline
        include "OmfRc::Util::#{name.camelcase}".constant
      rescue NameError
        begin
          # Then we try to require the file and include the module
          require "#{UTIL_DIR}/#{name}"
          include "OmfRc::Util::#{name.camelcase}".constant
        rescue LoadError => le
          logger.error le.message
        rescue NameError => ne
          logger.error ne.message
        end
      end
    end

    # Register a named utility entry with factory class, normally this should be done in the utility module
    #
    # @param [Symbol] name of the resource proxy
    # @example suppose we define a utility for iw command interaction
    #
    #   module OmfRc::Util::Iw
    #     include OmfRc::ResourceProxyDSL
    #
    #     # Let the factory know it is available
    #     register_utility :iw
    #   end
    def register_utility(name)
      name = name.to_sym
      OmfRc::ResourceFactory.register_utility(name)
    end

    # Register a configurable property
    #
    # @param [Symbol] name of the property
    # @yieldparam [AbstractResource] resource pass the current resource object to the block
    # @yieldparam [Object] value pass the value to be configured
    # @example suppose we define a utility for iw command interaction
    #
    #   module OmfRc::Util::Iw
    #     include OmfRc::ResourceProxyDSL
    #
    #     register_configure :freq do |resource, value|
    #       Command.execute("iw #{resource.hrn} set freq #{value}")
    #     end
    #
    #     # or use iterator to define multiple properties
    #     %w(freq channel type).each do |p|
    #       register_configure p do |resource, value|
    #         Command.execute("iw #{resource.hrn} set freq #{value}")
    #       end
    #     end
    #
    #     # or we can try to parse iw's help page to extract valid properties and then automatically register them
    #     Command.execute("iw help").chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq.each do |p|
    #       register_configure p do |resource, value|
    #         Command.execute("iw #{resource.hrn} set #{p} #{value}")
    #       end
    #     end
    #   end
    def register_configure(name, &register_block)
      define_method("configure_#{name.to_s}") do |*args, &block|
      register_block.call(self, *args, block) if register_block
      end
    end

    # Register a property that could be requested
    #
    # @param (see #register_configure)
    # @yieldparam [AbstractResource] resource pass the current resource object to the block
    # @example suppose we define a utility for iw command interaction
    #   module OmfRc::Util::Iw
    #     include OmfRc::ResourceProxyDSL
    #
    #     register_request :freq do |resource|
    #       Command.execute("iw #{resource.hrn} link").match(/^(freq):\W*(.+)$/) && $2
    #     end
    #
    #     # or we can grab everything from output of iw link command and return as a hash(mash)
    #     Command.execute("iw #{resource.hrn} link").chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
    #       v.match(/^(.+):\W*(.+)$/).tap do |m|
    #         m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
    #       end
    #     end
    #   end
    def register_request(name, &register_block)
      define_method("request_#{name.to_s}") do |*args|
        register_block.call(self) if register_block
      end
    end
  end
end
