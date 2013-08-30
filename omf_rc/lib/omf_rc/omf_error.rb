# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# Error during message processing,  include message related information cid and replyto, for publishing  errors to pubsub server
#
class OmfRc::MessageProcessError < StandardError
  attr_reader :cid, :replyto

  def initialize(cid, replyto, msg = nil)
    @cid = cid
    @replyto = replyto
    super(msg)
  end
end

class OmfRc::TopicNotSubscribedError < StandardError; end

# No method error that caused by configure/request unknown property
#
class OmfRc::UnknownPropertyError < NoMethodError
  def initialize(msg = nil)
    super(msg)
  end
end
