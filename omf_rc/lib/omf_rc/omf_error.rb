# Error during message processing,  include message related information context_id and inform_to, for publishing  errors to pubsub server
#
class OmfRc::MessageProcessError < StandardError
  attr_reader :context_id, :inform_to

  def initialize(context_id, inform_to, msg = nil)
    @context_id = context_id
    @inform_to = inform_to
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
