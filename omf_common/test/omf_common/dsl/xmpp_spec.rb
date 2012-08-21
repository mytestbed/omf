require 'test_helper'

include OmfCommon::DSL::Xmpp

describe OmfCommon::DSL::Xmpp do
  describe "when omf message related methods" do
    it "must generate omf create xml fragment" do
      m1 = create_message([type: 'engine'])
      m2 = create_message do |v|
        v.property('type', 'test')
      end
      m1.must_equal m2
      m1.name.must_equal 'create'
      m1.to_xml.must_match /<property key="type">engine<\/property>/
    end

    it "must generate omf configure xml fragment" do
      m1 = configure_message([throttle: 50])
      m2 = configure_message do |v|
        v.property('throttle', 50)
      end
      m1.must_equal m2
      m1.name.must_equal 'configure'
      m1.to_xml.must_match /<property key="throttle">50<\/property>/
    end

    it "must generate omf inform xml fragment" do
      m1 = inform_message([inform_type: 'CREATED'])
      m2 = inform_message do |v|
        v.property('inform_type', 'test')
      end
      m1.must_equal m2
      m1.name.must_equal 'inform'
      m1.to_xml.must_match /<property key="inform_type">CREATED<\/property>/
    end

    it "must generate omf release xml fragment" do
      m1 = release_message([resource_id: 100])
      m2 = release_message do |v|
        v.property('resource_id', 100)
      end
      m1.must_equal m2
      m1.name.must_equal 'release'
      m1.to_xml.must_match /<property key="resource_id">100<\/property>/
    end

    it "must generate omf request xml fragment" do
      m1 = request_message([:max_rpm, {:provider => {country: 'japan'}}, :max_power])
      m2 = request_message do |v|
        v.property('max_rpm')
        v.property('provider') do |p|
          p.element('country', 'japan')
        end
        v.property('max_power')
      end
      m1.must_equal m2
      m1.name.must_equal 'request'
      m1.to_xml.must_match /<property key="max_rpm"\/>/
      m1.to_xml.must_match /<property key="provider">/
      m1.to_xml.must_match /<country>japan<\/country>/
      m1.to_xml.must_match /<property key="max_power"\/>/
    end
  end
end

