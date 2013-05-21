# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_rc/resource_proxy/mock'

describe OmfRc::ResourceProxy::Mock do
  before do
    @xmpp = MiniTest::Mock.new
    @xmpp.expect(:subscribe, true, [String])

    OmfCommon.stub :comm, @xmpp do
      @mock = OmfRc::ResourceFactory.create(:mock, hrn: 'mock_test')
    end
  end

  describe "when included in the resource instance" do
    it "must provide hooks" do
      @mock.before_ready
      @mock.before_release
    end
  end
end
