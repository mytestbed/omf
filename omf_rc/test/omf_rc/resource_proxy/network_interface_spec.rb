require 'test_helper'
require 'omf_rc/resource_proxy/network_interface'

include OmfRc::ResourceProxy

describe NetworkInterface do
  before do
    @resource = NetworkInterface.create(:type => 'network_interface', :uid => 'eth0', :properties => {:ip => "127.0.0.1"})
  end

  after do
    Sequel::Model.db.from(NetworkInterface.table_name).truncate
  end

  describe "when it is created and provide set of properties" do
    it "must configure the resource with property key value pairs" do
      @resource.properties.ip.must_equal '127.0.0.1'
    end
  end
end

