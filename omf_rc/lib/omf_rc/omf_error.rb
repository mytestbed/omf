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

# Customised errors for resource controller (Proposing)
#
class OmfRc::Error < StandardError; end

class OmfRc::Error
  class UnknownProperty < OmfRc::Error; end
  # Try to create a resource with type not known to resource controller
  class UnknownResourceType < OmfRc::Error; end
  # Try to access a child resource provided by identifier but can not be found
  class UnknownChildResource < OmfRc::Error; end
  # Ask a parent to create a child but failed due to parent's proxy definition
  class InvalidResourceTypeToCreate < OmfRc::Error; end
  # Try to access a property but access specified in proxy definition would not allow.
  # e.g. configure when its init_only
  class PropertyAccessDenied < OmfRc::Error; end
end
