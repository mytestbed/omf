require 'test_helper'

MSG_NAMES = %w(create configure request inform release)
PROP_ELEMENTS = %w(p1 p2 p3)

describe OmfCommon::Message do
  describe "when constructing valid messages" do
    it "must return a create or configure XML element without failing" do
      %w(create configure).each do |msg_name|
        message = OmfCommon::Message.send(msg_name) do |m|
          PROP_ELEMENTS.each do |prop_element|
            m.property(prop_element, rand(100))
            m.property(prop_element, rand(100)) do |p|
              p.element('unit', 'test')
              p.element('precision', 'test')
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
      inform = OmfCommon::Message.inform('9012c3bc-68de-459a-ac9f-530cc7168e22') do |m|
        m.inform_type('CREATED')
      end.sign
      inform.valid?.must_equal true
    end
  end
end
