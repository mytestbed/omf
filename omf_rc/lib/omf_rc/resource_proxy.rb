module OmfRc::ResourceProxy
  PROXY_DIR = "omf_rc/resource_proxy"

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
        register_block.call if register_block
      end
    end
  end
end
