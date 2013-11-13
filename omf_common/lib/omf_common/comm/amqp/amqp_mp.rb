# Copyright (c) 2013 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'oml4r'

module OmfCommon
  class Comm
    class AMQP

      class MPPublished < OML4R::MPBase
        name :amqp_published
        param :time, :type => :double
        param :topic, :type => :string
        param :mid, :type => :string
      end

      class MPReceived < OML4R::MPBase
        name :amqp_received
        param :time, :type => :double
        param :topic, :type => :string
        param :mid, :type => :string
      end

    end
  end
end

