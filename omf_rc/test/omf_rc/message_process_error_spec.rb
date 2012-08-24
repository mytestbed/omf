require 'test_helper'

describe OmfRc::MessageProcessError do
  it "must be able to initialised" do
    mpe = OmfRc::MessageProcessError.new('test_context_id', 'inform_to_address', 'error_messsage')
    mpe.context_id.must_equal 'test_context_id'
    mpe.inform_to.must_equal 'inform_to_address'
    mpe.message.must_equal 'error_messsage'
    mpe.must_be_kind_of StandardError
  end
end
