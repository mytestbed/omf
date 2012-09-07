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

    it "must provide hooks" do
      @node.before_ready
      @node.before_release
    end

    it "must provide a list of supported network devices" do
      devices = [
        { name: 'eth0', driver: 'e1000e', category: 'net', subcategory: nil, proxy: 'net' },
        { name: 'wlan0', driver: 'iwlwifi', category: 'net', subcategory: 'wlan', proxy: 'wlan' }
      ]

      Dir.stub :chdir, proc { |*args, &block| block.call } do
        glob_proc = proc do |pattern|
          sys_dir = "#{File.dirname(__FILE__)}/../../fixture/sys/class"
          case pattern
          when "net"
            ["#{sys_dir}/net"]
          when "net/*"
            ["#{sys_dir}/net/eth0", "#{sys_dir}/net/wlan0"]
          end
        end
        Dir.stub :glob, glob_proc do
          @node.request_devices.must_be_kind_of Array
          @node.request_devices.must_equal devices
        end
      end
    end
  end
end
