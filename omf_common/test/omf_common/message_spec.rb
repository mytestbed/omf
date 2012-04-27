require 'test_helper'

PROP_ELEMENTS = %w(p1 p2 p3)

describe OmfCommon::Message do
  describe "when constructing valid messages" do
    it "must return a create or configure XML element without failing" do
      %w(create configure).each do |msg_name|
        message = OmfCommon::Message.send(msg_name) do |m|
          PROP_ELEMENTS.each_with_index do |prop_element, index|
            if index == 0
              m.property(prop_element, rand(100))
            else
              m.property(prop_element, rand(100)) do |p|
                p.element('unit', 'test')
                p.element('precision', 'test')
              end
            end
          end
        end.sign
        message.valid?.must_equal true
      end
    end

    it "must return a request XML element without failing" do
      request = OmfCommon::Message.request('foo@bar') do |m|
        PROP_ELEMENTS.each do |prop_element|
          m.property(prop_element) do |p|
            p.element('min_value', 'test')
            p.element('max_value', 'test')
          end
        end
      end.sign
      request.valid?.must_equal true
    end

    it "must return a release XML element without failing" do
      release = OmfCommon::Message.release.sign
      release.valid?.must_equal true
    end

    it "must return a inform XML element without failing" do
      inform = OmfCommon::Message.inform('9012c3bc-68de-459a-ac9f-530cc7168e22', 'CREATED') do |m|
        m.element('resource_id', 'test')
        m.element('resource_address', 'test')
        PROP_ELEMENTS.each do |prop_element|
          m.property(prop_element) do |p|
            p.element('current', 'test')
            p.element('target', 'test')
          end
        end
      end.sign
      inform.valid?.must_equal true
    end
  end

  describe "must be able to parse a XML element into Message object" do
    it "must behave" do
      xml = OmfCommon::Message.create do |m|
        m.property('type', 'vm')
        m.property('os', 'debian')
        m.property('memory', 1024) do |p|
          p.element('unit', 'mb')
          p.element('precision', '0')
        end
      end.sign.to_xml

      message = OmfCommon::Message.parse(xml)

      message.must_be_kind_of OmfCommon::Message
      message.xpath("//xmlns:property", :xmlns => "http://schema.mytestbed.net/6.0/protocol").size.must_equal 3
    end
  end
end
