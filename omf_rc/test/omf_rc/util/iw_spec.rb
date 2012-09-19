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

    it "must initialise some wpa & hostapd defaults" do
      @wlan00.request_wpa_conf.must_equal "/tmp/wpa.wlan00.conf"
      @wlan00.request_wpa_pid.must_equal "/tmp/wpa.wlan00.pid"
      @wlan00.request_ap_conf.must_equal "/tmp/hostapd.wlan00.conf"
      @wlan00.request_ap_pid.must_equal "/tmp/hostapd.wlan00.pid"
    end

    it "must be able to set up wlan connection in different modes" do
      lambda { @wlan00.configure_mode(mode: 'master') }.must_raise ArgumentError
      lambda { @wlan00.configure_mode(mode: 'bob') }.must_raise ArgumentError
      lambda { @wlan00.configure_mode(mode: 'master', hw_mode: 'x') }.must_raise ArgumentError
      lambda { @wlan00.configure_mode(hw_mode: 'x') }.must_raise ArgumentError


      Cocaine::CommandLine.stub(:new, @command) do
        3.times { @command.expect(:run, true) }

        @wlan00.configure_mode(mode: 'master', channel: 1, essid: 'bob', hw_mode: 'b')
        File.open("/tmp/hostapd.wlan00.conf") do |f|
          f.read.must_match "driver=nl80211\ninterface=wlan00\nssid=bob\nchannel=1\nhw_mode=b\n"
        end

        3.times { @command.expect(:run, true) }

        @wlan00.configure_mode(mode: 'master', channel: 1, essid: 'bob', hw_mode: 'n')
        File.open("/tmp/hostapd.wlan00.conf") do |f|
          f.read.must_match "driver=nl80211\ninterface=wlan00\nssid=bob\nchannel=1\nhw_mode=g\nwmm_enabled=1\nieee80211n=1\nht_capab=\[HT20\-\]\n"
        end
      end
    end
  end
end
