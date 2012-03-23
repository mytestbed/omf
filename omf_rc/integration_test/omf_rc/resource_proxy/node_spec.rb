require 'test_helper'
require 'omf_rc/resource_proxy'

include OmfRc::ResourceProxy

describe Node do
  before do
    @resource = Abstract.new(type: 'abstract', properties: { pubsub: "mytestbed.net" })
    @node = @resource.create(:type => 'node', :uid => 'monaco')
  end

  describe "when configured with properties" do
    it "must run the underline commands" do
    end
  end

  describe "when properties requested" do
    it "must return an array with actual properties" do
      @resource.request([:devices], {:uid => 'monaco'}).first.devices.each do |device|
        device.type.wont_be_nil
        device.name.wont_be_nil
      end
    end
  end
end

