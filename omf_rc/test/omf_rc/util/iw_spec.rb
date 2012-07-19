require 'minitest/mock'
require 'test_helper'
require 'omf_rc/util/iw'

describe OmfRc::Util::Iw do
  describe "when included in the resource instance" do
    before do
      OmfCommon::Command.stub :execute, fixture("iw/help") do
        module OmfRc::ResourceProxy::IwTest
          include OmfRc::ResourceProxyDSL
          register_proxy :iw_test
          utility :iw
        end
      end
    end

    it "must provide features defined in proxy" do
      %w(request_link configure_name configure_channel configure_bitrates).each do |m|
        OmfRc::Util::Iw.method_defined?(m).must_equal true
      end
    end

    it "could request properties of the wifi device" do
      OmfCommon::Command.stub :execute, fixture("iw/link") do
        OmfRc::ResourceFactory.new(:iw_test, hrn: 'wlan00').request_link.keys.must_include "ssid"
      end
    end

    it "could configure the device's prorperty" do
      OmfCommon::Command.stub :execute, true do
        OmfRc::ResourceFactory.new(:iw_test, hrn: 'wlan00').configure_power_save.must_equal true
      end
    end
  end
end
