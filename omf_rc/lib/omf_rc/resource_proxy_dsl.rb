# DSL contains some helper methods to ease the process defining resource proxies
#
module OmfRc::ResourceProxyDSL
  PROXY_DIR = "omf_rc/resource_proxy"
  UTIL_DIR = "omf_rc/util"

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Methods defined here will be available in resource/utility definition files
  #
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
    # Currently the system supports these hooks:
    #
    # * before_ready, called when a resource created, before creating an associated pubsub topic
    # * before_release, called before a resource released
    # * before_create, called before parent creates the child resource. (in the context of parent resource)
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
    #    # before_create hook
    #    #
    #    # the optional block will have access to three variables:
    #    # * resource: the parent resource itself
    #    # * new_resource_type: a string or symbol represents the new resource to be created
    #    # * new_resource_options: the options hash to be passed to the new resource
    #    #
    #    # this hook enable us to do things like:
    #    # * validating child resources: e.g. if parent could create this new resource
    #    # * setting up default child properties based on parent's property value
    #    hook :before_create do |resource, new_resource_type, new_resource_options|
    #      if new_resource_type.to_sym == :wifi
    #        logger.info "Resource type wifi is allowed"
    #      else
    #        raise "Go away, I can't create #{new_resource_type}"
    #      end
    #      new_resource_options.property ||= Hashie::Mash.new
    #      new_resource_options.property.node_info = "Node #{resource.uid}"
    #    end
    #
    #    hook :before_ready do |resource|
    #      logger.info "#{resource.uid} is now ready"
    #    end
    #
    #    hook :before_release do |resource|
    #      logger.info "#{resource.uid} is now released"
    #    end
    #   end
    def hook(name, &register_block)
      define_method(name) do |*args, &block|
        register_block.call(self, *args, block) if register_block
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
        include "OmfRc::Util::#{name.camelize}".constantize
        extend "OmfRc::Util::#{name.camelize}".constantize
      rescue NameError
        begin
          # Then we try to require the file and include the module
          require "#{UTIL_DIR}/#{name}"
          include "OmfRc::Util::#{name.camelize}".constantize
          extend "OmfRc::Util::#{name.camelize}".constantize
        rescue LoadError => le
          logger.error le.message
        rescue NameError => ne
          logger.error ne.message
        end
      end
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
    #     configure :freq do |resource, value|
    #       Command.execute("iw #{resource.hrn} set freq #{value}")
    #     end
    #
    #     # or use iterator to define multiple properties
    #     %w(freq channel type).each do |p|
    #       configure p do |resource, value|
    #         Command.execute("iw #{resource.hrn} set freq #{value}")
    #       end
    #     end
    #
    #     # or we can try to parse iw's help page to extract valid properties and then automatically register them
    #     Command.execute("iw help").chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq.each do |p|
    #       configure p do |resource, value|
    #         Command.execute("iw #{resource.hrn} set #{p} #{value}")
    #       end
    #     end
    #   end
    #
    # @see OmfCommon::Command.execute
    #
    def configure(name, &register_block)
      define_method("configure_#{name.to_s}") do |*args, &block|
        args[0] = Hashie::Mash.new(args[0]) if args[0].class == Hash
        register_block.call(self, *args, block) if register_block
      end
    end

    # Register a property that could be requested
    #
    # @param (see #configure)
    # @yieldparam [AbstractResource] resource pass the current resource object to the block
    # @example suppose we define a utility for iw command interaction
    #   module OmfRc::Util::Iw
    #     include OmfRc::ResourceProxyDSL
    #
    #     request :freq do |resource|
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
    def request(name, &register_block)
      define_method("request_#{name.to_s}") do |*args, &block|
        args[0] = Hashie::Mash.new(args[0]) if args[0].class == Hash
        register_block.call(self, *args, block) if register_block
      end
    end

    # Define an arbitrary method to do some work, can be included in configure & request block
    #
    # @param (see #configure)
    # @yieldparam [AbstractResource] resource pass the current resource object to the block
    # @example suppose we define a simple os checking method
    #
    #   work :os do
    #     Command.execute("uname")
    #   end
    #
    #   # then this os method will be available in all proxy definitions which includes this work method definition.
    #   # if for some reason you need to call 'os' method within the same module, you need to access it via the resource instance.
    #
    #   work :install_software do |resource|
    #     raise 'Can not support non-linux distro yet' if resource.os == 'Linux'
    #   end
    def work(name, &register_block)
      define_method(name) do |*args, &block|
        register_block.call(self, *args, block) if register_block
      end
    end
  end
end
