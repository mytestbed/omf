require 'test_helper'
require 'omf_rc/resource_proxy'

include OmfRc::ResourceProxy

describe App do
  before do
    @resource = AbstractResource.new(properties: { pubsub: "mytestbed.net" })
    @app1 = @resource.create(:type => 'app', :uid => 'zathura')
    @app2 = @resource.create(:type => 'app', :uid => 'bob')
  end

  describe "when configured with properties" do
    it "must run the underline commands" do
    end
  end

  describe "when properties requested" do
    it "must return an array with actual properties" do
      @resource.request([:version], {:uid => 'zathura'}).first.version.must_match /[\d|\.|-]+/
      @resource.request([:version], {:uid => 'bob'}).first.version.must_be_nil
    end
  end
end

