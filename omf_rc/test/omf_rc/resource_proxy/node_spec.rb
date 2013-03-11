require 'test_helper'
require 'omf_rc/resource_proxy/node'

describe OmfRc::ResourceProxy::Node do
  before do
    @xmpp = MiniTest::Mock.new
    @xmpp.expect(:subscribe, true, [Array])

    OmfCommon.stub :comm, @xmpp do
      @node = OmfRc::ResourceFactory.new(:node, hrn: 'node_test')
    end
  end

  describe "when included in the resource instance" do
    it "must be able to tell registered proxies" do
      @node.request_proxies.must_include :node
    end

    it "must provide a list of supported network devices" do
      devices = [
        { name: 'eth0', driver: 'e1000e', category: 'net', proxy: 'net' },
        { name: 'phy0', driver: 'iwlwifi', category: 'net', subcategory: 'wlan', proxy: 'wlan' }
      ]

      glob_proc = proc do |pattern|
        sys_dir = "#{File.dirname(__FILE__)}/../../fixture/sys/class"
        case pattern
        when "/sys/class/net"
          ["#{sys_dir}/net"]
        when "/sys/class/ieee80211"
          ["#{sys_dir}/ieee80211"]
        when "/sys/class/ieee80211/*"
          ["#{sys_dir}/ieee80211/phy0"]
        when "/sys/class/net/eth*"
          ["#{sys_dir}/net/eth0"]
        end
      end
      Dir.stub :glob, glob_proc do
        @node.request_devices.must_be_kind_of Array
        node_devices = @node.request_devices
        node_devices.size.must_equal 2
        node_devices[0][:name].must_equal 'eth0'
        node_devices[1][:name].must_equal 'phy0'
      end
    end

    it "must provide a list of created applications" do
      OmfCommon.stub :comm, @xmpp do
        @xmpp.expect(:subscribe, true, [Array])
        @node.create(:application, { :uid => 'app_test', :hrn => 'app_test' })

        @node.request_applications.must_equal [
          { name: 'app_test', type: :application, uid: 'app_test' }
        ]
      end
    end

    it "must provide a list of created interfaces" do
      OmfCommon.stub :comm, @xmpp do
        devices = [
          { name: 'eth0', driver: 'e1000e', category: 'net', proxy: 'net' },
          { name: 'phy0', driver: 'iwlwifi', category: 'net', subcategory: 'wlan', proxy: 'wlan' }
        ]
        @node.stub :request_devices, devices do
          2.times { @xmpp.expect(:subscribe, true, [String]) }
          @node.create(:wlan, { :uid => 'wlan0', :if_name => 'wlan0' })
          @node.create(:net, { :uid => 'eth0', :if_name => 'eth0' })

          @node.request_interfaces.must_equal [
            { name: 'eth0', type: :net, uid: 'eth0' },
            { name: 'wlan0', type: :wlan, uid: 'wlan0' }
          ]
        end
      end
    end
  end
end
