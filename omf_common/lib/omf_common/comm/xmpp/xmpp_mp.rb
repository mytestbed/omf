# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'oml4r'

module OmfCommon
  module DSL
    module Xmpp
      class MPConnection < OML4R::MPBase
        name :xmpp_connections
        param :time, :type => :double
        param :jid, :type => :string
        param :operation, :type => :string
      end

      class MPPublished < OML4R::MPBase
        name :xmpp_published
        param :time, :type => :double
        param :jid, :type => :string
        param :topic, :type => :string
        param :mid, :type => :string
      end

      class MPReceived < OML4R::MPBase
        name :xmpp_received
        param :time, :type => :double
        param :jid, :type => :string
        param :topic, :type => :string
        param :mid, :type => :string
      end

      class MPSubscription < OML4R::MPBase
        name :xmpp_subscriptions
        param :time, :type => :double
        param :jid, :type => :string
        param :operation, :type => :string
        param :topic, :type => :string
      end
    end
  end
end
