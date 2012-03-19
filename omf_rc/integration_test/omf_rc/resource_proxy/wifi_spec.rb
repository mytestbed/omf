require 'test_helper'
require 'omf_rc/resource_proxy'

include OmfRc::ResourceProxy

describe Wifi do
  before do
    @resource = Abstract.new(type: 'abstract', properties: { pubsub: "mytestbed.net" })
    @wifi = @resource.create(:type => 'wifi', :uid => 'wlan0')
  end

  describe "when configured with properties" do
    it "must run the underline commands" do
    end
  end

  describe "when properties requested" do
    it "must return an array with actual properties" do
      @resource.request([:essid, :mode, :frequency, :tx_power, :rts], {:type => 'wifi'}).each do |wifi|
        wifi.essid.wont_be_nil
        wifi.mode.wont_be_nil
        wifi.frequency.wont_be_nil
      end
    end
  end
end

