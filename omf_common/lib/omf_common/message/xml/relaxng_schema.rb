# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'singleton'

module OmfCommon
  class RelaxNGSchema
    include Singleton

    SCHEMA_FILE = "#{File.dirname(__FILE__)}/../../protocol/#{OmfCommon::PROTOCOL_VERSION}.rng"

    def initialize
      @rng = File.read(SCHEMA_FILE)
    end

    def validate(document)
      Nokogiri::XML::RelaxNG(@rng).validate(document)
    end
  end
end
