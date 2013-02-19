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

# No method error that caused by configure/request unknown property
#
class OmfRc::UnknownPropertyError < NoMethodError
  def initialize(msg = nil)
    super(msg)
  end
end
