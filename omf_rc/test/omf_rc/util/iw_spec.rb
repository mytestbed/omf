require 'minitest/mock'
require 'test_helper'

OmfCommon::Command.stub :execute, fixture("iw/help") do
  require 'omf_rc/util/iw'
end

describe OmfRc::Util::Iw do
  describe "when included in the resource instance" do
    before do
      @command = MiniTest::Mock.new

      OmfCommon::Command.stub :execute, fixture("iw/help") do
        module OmfRc::ResourceProxy::IwTest
          include OmfRc::ResourceProxyDSL
          register_proxy :iw_test
          utility :iw
        end
      end

      @wlan00 = OmfRc::ResourceFactory.new(:iw_test, hrn: 'wlan00')
    end

    it "must provide features defined in proxy" do
      %w(request_link configure_name configure_channel configure_bitrates).each do |m|
        OmfRc::Util::Iw.method_defined?(m).must_equal true
      end
    end

    it "could request properties of the wifi device" do
      Cocaine::CommandLine.stub(:new, @command) do
        @command.expect(:run, fixture("iw/link"))
        @wlan00.request_link.keys.must_include "ssid"
        @command.verify
      end
    end

    it "could configure the device's prorperty" do
      Cocaine::CommandLine.stub(:new, @command) do
        @command.expect(:run, true)
        @wlan00.configure_power_save(true)
        @command.verify
      end
    end
  end
end
