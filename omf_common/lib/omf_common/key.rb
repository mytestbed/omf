# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'openssl'
require 'singleton'

module OmfCommon
  class Key
    include Singleton

    attr_accessor :private_key

    def import(filename)
      self.private_key = OpenSSL::PKey.read(File.read(filename))
    end
  end
end
