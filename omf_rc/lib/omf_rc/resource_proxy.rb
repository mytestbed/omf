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
  end
end
