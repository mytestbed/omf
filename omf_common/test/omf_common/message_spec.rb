require 'test_helper'

MSG_NAMES = %w(create configure request inform release)
PROP_ELEMENTS = %w(p1 p2 p3)

describe OmfCommon::Message do
  describe "when constructing valid messages" do
    it "must return a proper XML element without failing" do
      MSG_NAMES.each do |msg_name|
        message = OmfCommon::Message.send(msg_name) do |m|
          PROP_ELEMENTS.each do |prop_element|
            m.property(prop_element, rand(100))
          end
        end
        message.valid?.must_equal true
      end
    end
  end
end
