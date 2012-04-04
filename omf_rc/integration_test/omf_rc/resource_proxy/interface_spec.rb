require 'test_helper'
require 'omf_rc/resource_proxy'

include OmfRc::ResourceProxy

describe Interface do
  before do
    @resource = AbstractResource.new(properties: { pubsub: "mytestbed.net" })
    @interface = @resource.create(:type => 'interface', :uid => 'eth0')
  end

  describe "when configured with properties" do
    it "must run the underline commands" do
    end
  end

  describe "when properties requested" do
    it "must return an array with actual properties" do
      @resource.request([:mac, :ip], {:type => 'interface'}).each do |interface|
        interface.mac.must_match /([\da-fA-F]+:){5}[\da-fA-F]+/
        interface.ip.must_match /([.\d]+\.){3}[.\d]+/
      end
    end
  end
end

