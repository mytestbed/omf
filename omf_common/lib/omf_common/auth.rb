

module OmfCommon
  module Auth
    
    class AuthException < Exception; end
    
    def self.init(opts = {})
      CertificateStore.init(opts)
    end    
  end
end

require 'omf_common/auth/certificate_store'
require 'omf_common/auth/certificate'