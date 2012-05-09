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

    def register_bootstrap(&register_block)
      define_method(:bootstrap) do |*args, &block|
        register_block.call if register_block
      end
    end

    def register_cleanup(&register_block)
      define_method(:cleanup) do |*args, &block|
        register_block.call(block) if register_block
      end
    end

    def utility(name)
      name = name.to_s
      begin
        require "#{UTIL_DIR}/#{name}"
      rescue LoadError => e
        logger.warn e.message
      end
      include "OmfRc::Util::#{name.camelcase}".constant
    end

    def register_utility(name)
      name = name.to_sym
      OmfRc::ResourceFactory.register_utility(name)
    end

    def register_configure(name, &register_block)
      define_method("configure_#{name.to_s}") do |*args, &block|
        raise ArgumentError "Missing value to conifgure property" if args.empty?
        register_block.call(args[0]) if register_block
      end
    end

    def register_request(name, &register_block)
      define_method("request_#{name.to_s}") do |*args, &block|
        register_block.call(block) if block if register_block
      end
    end
  end

end
