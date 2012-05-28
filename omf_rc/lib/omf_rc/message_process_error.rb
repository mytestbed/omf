class OmfRc::MessageProcessError < StandardError
  attr_reader :context_id, :inform_to

  def initialize(context_id, inform_to, msg = nil)
    @context_id = context_id
    @inform_to = inform_to
    super(msg)
  end
end
