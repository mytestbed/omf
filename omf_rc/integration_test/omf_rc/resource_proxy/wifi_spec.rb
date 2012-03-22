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
      @resource.request([:ssid, :freq, :ssid, :freq, :rx, :tx, :signal, :tx_bitrate], {:type => 'wifi'}).each do |wifi|
        wifi.ssid.wont_be_nil
        wifi.freq.wont_be_nil
        wifi.rx.wont_be_nil
        wifi.tx.wont_be_nil
        wifi.signal.wont_be_nil
        wifi.tx_bitrate.wont_be_nil
      end
    end
  end
end

