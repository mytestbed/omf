require 'minitest/mock'
require 'test_helper'

require 'omf_rc/util/ip'

describe OmfRc::Util::Ip do
  describe "when included in the resource instance" do
    before do
      module OmfRc::ResourceProxy::IpTest
        include OmfRc::ResourceProxyDSL
        register_proxy :ip_test
        utility :ip
      end

      @xmpp = MiniTest::Mock.new
      @xmpp.expect(:subscribe, true, [Array])

      @command = MiniTest::Mock.new

      OmfCommon.stub :comm, @xmpp do
        @wlan00 = OmfRc::ResourceFactory.new(:ip_test, hrn: 'wlan00')
      end
    end

    it "must provide features defined in proxy" do
      %w(request_ip_addr request_mac_addr configure_ip_addr).each do |m|
        OmfRc::Util::Ip.method_defined?(m).must_equal true
      end
    end

    it "could request ip address of the device" do
      Cocaine::CommandLine.stub(:new, @command) do
        @command.expect(:run, fixture("ip/addr_show"))
        @wlan00.request_ip_addr.must_equal "192.168.1.124/24"
        @command.verify
      end
    end

    it "could request mac address of the device" do
      Cocaine::CommandLine.stub(:new, @command) do
        @command.expect(:run, fixture("ip/addr_show"))
        @wlan00.request_mac_addr.must_equal "00:00:00:29:00:00"
        @command.verify
      end
    end

    it "could configure the device's prorperty" do
      lambda { @wlan00.configure_ip_addr("192.168.1.124/24") }.must_raise Cocaine::ExitStatusError
      Cocaine::CommandLine.stub(:new, @command) do
        3.times do
          @command.expect(:run, "")
        end
        @command.expect(:run, fixture("ip/addr_show"))
        @wlan00.configure_ip_addr("192.168.1.124/24")
        @command.verify
      end
    end
  end
end
