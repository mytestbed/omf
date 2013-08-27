# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'minitest/mock'
require 'test_helper'
require 'cocaine'

@command = MiniTest::Mock.new

Cocaine::CommandLine.stub(:new, @command) do
  @command.expect(:run, fixture("iw/help"))
  require 'omf_rc/util/iw'

  describe OmfRc::Util::Iw do
    describe "when included in the resource instance" do
      before do
        @command = MiniTest::Mock.new

        module OmfRc::ResourceProxy::IwTest
          include OmfRc::ResourceProxyDSL

          register_proxy :iw_test

          utility :iw

          property :if_name
          property :phy
        end

        mock_comm_in_res_proxy
        mock_topics_in_res_proxy(resources: [:w00])
        @wlan00 = OmfRc::ResourceFactory.create(:iw_test, uid: :w00, hrn: 'wlan00', property: { phy: 'phy00', if_name: 'wlan1' })
      end

      after do
        unmock_comm_in_res_proxy
        @wlan00 = nil
      end

      it "must provide features defined in proxy" do
        %w(request_link configure_name configure_channel configure_bitrates).each do |m|
          OmfRc::Util::Iw.method_defined?(m).must_equal true
        end
      end

      it "could request properties of the wifi interface" do
        Cocaine::CommandLine.stub(:new, @command) do
          @command.expect(:run, fixture("iw/link"))
          @wlan00.request_link.keys.must_include "ssid"
          @command.verify
        end
      end

      it "could request info of the wifi interface" do
        Cocaine::CommandLine.stub(:new, @command) do
          @command.expect(:run, fixture("iw/info"))
          @wlan00.request_info.keys.must_equal ["ifindex", "type", "wiphy"]
          @command.verify
        end
      end

      it "could configure the device's property" do
        Cocaine::CommandLine.stub(:new, @command) do
          @command.expect(:run, true)
          @wlan00.configure_power_save(true)
          @command.verify
        end
      end

      it "must could initialise wpa config/pid file path" do
        @wlan00.init_ap_conf_pid
        @wlan00.property.ap_conf.must_match /\/hostapd\.wlan1.+\.conf/
        @wlan00.property.ap_pid.must_match /\/hostapd\.wlan1.+\.pid/
      end

      it "must could initialise wpa config/pid file path" do
        @wlan00.init_wpa_conf_pid
        @wlan00.property.wpa_conf.must_match /\/wpa\.wlan1.+\.conf/
        @wlan00.property.wpa_pid.must_match /\/wpa\.wlan1.+\.pid/
      end

      it "could delete current interface" do
        Cocaine::CommandLine.stub(:new, @command) do
          @command.expect(:run, true)
          @wlan00.delete_interface
          @command.verify
        end
      end

      it "could add a new interface" do
        Cocaine::CommandLine.stub(:new, @command) do
          @command.expect(:run, true)
          @wlan00.add_interface(:managed)
          @command.verify
        end
      end

      it "must be able to validate iw parameters when setting up mode" do
        lambda { @wlan00.configure_mode(mode: 'master') }.must_raise ArgumentError
        lambda { @wlan00.configure_mode(mode: 'bob') }.must_raise ArgumentError
        lambda { @wlan00.configure_mode(mode: 'master', hw_mode: 'x') }.must_raise ArgumentError
        lambda { @wlan00.configure_mode(hw_mode: 'x') }.must_raise ArgumentError
      end

      it "must be able to configure as master mode" do
        Cocaine::CommandLine.stub(:new, @command) do
          3.times { @command.expect(:run, true) }

          @wlan00.configure_mode(mode: 'master', channel: 1, essid: 'bob', hw_mode: 'b')
          File.open(@wlan00.property.ap_conf) do |f|
            f.read.must_match "driver=nl80211\ninterface=wlan1\nssid=bob\nchannel=1\nhw_mode=b\n"
          end

          3.times { @command.expect(:run, true) }

          @wlan00.configure_mode(mode: 'master', channel: 1, essid: 'bob', hw_mode: 'n')
          File.open(@wlan00.property.ap_conf) do |f|
            f.read.must_match "driver=nl80211\ninterface=wlan1\nssid=bob\nchannel=1\nhw_mode=g\nwmm_enabled=1\nieee80211n=1\nht_capab=\[HT20\-\]\n"
          end

          3.times { @command.expect(:run, true) }

          @wlan00.configure_mode(mode: 'master', channel: 16, essid: 'bob', hw_mode: 'n')
          File.open(@wlan00.property.ap_conf) do |f|
            f.read.must_match "driver=nl80211\ninterface=wlan1\nssid=bob\nchannel=16\nhw_mode=a\nwmm_enabled=1\nieee80211n=1\nht_capab=\[HT20\-\]\n"
          end

          @command.verify
        end
      end

      it "must be able to configure as managed mode" do
        Cocaine::CommandLine.stub(:new, @command) do
          3.times { @command.expect(:run, true) }

          @wlan00.configure_mode(mode: 'managed', essid: 'bob')
          File.open(@wlan00.property.wpa_conf) do |f|
            f.read.must_match "network={\n  ssid=\"bob\"\n  scan_ssid=1\n  key_mgmt=NONE\n}"
          end

          @command.verify
        end
      end

      it "must be able to configure as adhoc/ibss mode" do
        Cocaine::CommandLine.stub(:new, @command) do
          4.times { @command.expect(:run, true) }

          @wlan00.configure_mode(mode: 'adhoc', essid: 'bob', frequency: 2412)
          @command.verify
        end
      end

      it "must be able to configure as monitor mode" do
        Cocaine::CommandLine.stub(:new, @command) do
          3.times { @command.expect(:run, true) }

          @wlan00.configure_mode(mode: 'monitor')
          @command.verify
        end
      end
    end
  end
end
