# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'omf_common/auth'

module OmfCommon::Auth::PDP
  class TestPDP

    def initialize(opts = {})
      puts "AUTH INIT>>> #{opts}"
    end

    def authorize(msg, &block)
      puts "AUTH(#{msg.issuer})>>> #{msg}"
      sender = msg.src.address
      msg
    end
  end
end
