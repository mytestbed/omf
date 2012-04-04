module OmfRc::ResourceProxy::Util
  UTIL_DIR = "omf_rc/resource_proxy/util"

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def utility(name)
      name = name.to_s
      require "#{UTIL_DIR}/#{name}"
      include "OmfRc::ResourceProxy::Util::#{name.camelcase}".constant
    end
  end
end
