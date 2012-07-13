require 'test_helper'
require 'mock_helper'

mock_execute(fixture("iw/help"), "iw help")

require 'omf_rc/util/iw'

describe OmfRc::Util::Iw do
  describe "when included in the resource instance" do
    before do
      module OmfRc::ResourceProxy::IwTest
        include OmfRc::ResourceProxyDSL
        register_proxy :iw_test
        utility :iw
      end
    end

    after do
      mock_verify_execute
    end

    it "must provide features defined in proxy" do
      %w(request_link configure_name configure_channel configure_bitrates).each do |m|
        OmfRc::Util::Iw.method_defined?(m).must_equal true
      end
    end

    it "could request properties of the wifi device" do
      mock_execute(fixture("iw/link"), "iw wlan00 link")
      OmfRc::ResourceFactory.new(:iw_test, hrn: 'wlan00').request_link.keys.must_include "ssid"
    end

    it "could configure the device's prorperty" do
      mock_execute(nil, /iw wlan00 set */)
      OmfRc::ResourceFactory.new(:iw_test, hrn: 'wlan00').configure_power_save.must_be_nil
    end
  end
end
