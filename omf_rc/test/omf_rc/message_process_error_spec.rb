# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

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
