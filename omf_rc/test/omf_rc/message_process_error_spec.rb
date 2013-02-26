require 'test_helper'

describe OmfRc::MessageProcessError do
  it "must be able to initialised" do
    mpe = OmfRc::MessageProcessError.new('test_cid', 'replyto_address', 'error_messsage')
    mpe.cid.must_equal 'test_cid'
    mpe.replyto.must_equal 'replyto_address'
    mpe.message.must_equal 'error_messsage'
    mpe.must_be_kind_of StandardError
  end
end
