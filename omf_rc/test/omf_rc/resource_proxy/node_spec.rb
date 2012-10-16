require 'test_helper'
require 'omf_rc/resource_proxy/node'

describe OmfRc::ResourceProxy::Node do
  before do
    @node = OmfRc::ResourceFactory.new(:node, hrn: 'node_test')
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
        @node.request_devices.must_equal devices
      end
    end

    it "must provide a list of created applications" do
      @node.create(:generic_application, { :uid => 'app_test', :hrn => 'app_test' })

      @node.request_applications.must_equal [
        { name: 'app_test', type: 'generic_application', uid: 'app_test' }
      ]
    end

    it "must provide a list of created interfaces" do
      @node.create(:wlan, { :uid => 'wlan0', :hrn => 'wlan0' })
      @node.create(:net, { :uid => 'eth0', :hrn => 'eth0' })

      @node.request_interfaces.must_equal [
        { name: 'eth0', type: 'net', uid: 'eth0' },
        { name: 'wlan0', type: 'wlan', uid: 'wlan0' }
      ]
    end
  end
end
