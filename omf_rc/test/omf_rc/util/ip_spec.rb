# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

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

      @command = MiniTest::Mock.new

      mock_comm_in_res_proxy
      mock_topics_in_res_proxy(resources: [:w00])
      @wlan00 = OmfRc::ResourceFactory.create(:ip_test, uid: :w00, hrn: 'wlan00')
    end

    after do
      unmock_comm_in_res_proxy
      @wlan00 = nil
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

    it "could configure the device's property" do
      # cdw: disabled this call since it actually tried to run "ip" on my system !?
      # lambda { @wlan00.configure_ip_addr("192.168.1.124/24") }.must_raise Cocaine::ExitStatusError
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
