module OmfRc::Util
  UTIL_DIR = "omf_rc/util"

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
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
        block.call(register_block.call) if block if register_block
      end
    end
  end
end
