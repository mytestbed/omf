module OmfRc::ResourceProxyDSL
  PROXY_DIR = "omf_rc/resource_proxy"
  UTIL_DIR = "omf_rc/util"

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def register_proxy(name)
      name = name.to_sym
      OmfRc::ResourceFactory.register_proxy(name)
    end

    def register_hook(name, &register_block)
      define_method(name) do
        register_block.call if register_block
      end
    end

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

    def register_utility(name)
      name = name.to_sym
      OmfRc::ResourceFactory.register_utility(name)
    end

    def register_configure(name, &register_block)
      define_method("configure_#{name.to_s}") do |*args, &block|
        raise ArgumentError "Missing value to conifgure property" if args.empty?
        register_block.call(args[0], block) if register_block
      end
    end

    def register_request(name, &register_block)
      define_method("request_#{name.to_s}") do |*args, &block|
        register_block.call(block) if block if register_block
      end
    end
  end

end
