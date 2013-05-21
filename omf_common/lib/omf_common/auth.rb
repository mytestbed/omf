# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.



module OmfCommon
  module Auth

    class AuthException < StandardError; end

    def self.init(opts = {})
      CertificateStore.init(opts)
    end
  end
end

require 'omf_common/auth/certificate_store'
require 'omf_common/auth/certificate'
