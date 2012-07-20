require 'test_helper'

include OmfCommon

PROP_ELEMENTS = %w(p1 p2 p3)

describe OmfCommon::Message do
  describe "when constructing valid messages" do
    it "must return a create or configure XML element without failing" do
      %w(create configure).each do |msg_name|
        message = Message.__send__(msg_name) do |m|
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
        end
        message.valid?.must_equal true
      end
    end

    it "must return a request XML element without failing" do
      request = Message.request('foo@bar') do |m|
        PROP_ELEMENTS.each do |prop_element|
          m.property(prop_element) do |p|
            p.element('min_value', 'test')
            p.element('max_value', 'test')
          end
        end
      end
      request.valid?.must_equal true
    end

    it "must return a release XML element without failing" do
      release = Message.release
      release.valid?.must_equal true
    end

    it "must return a inform XML element without failing" do
      inform = Message.inform('CREATED', '9012c3bc-68de-459a-ac9f-530cc7168e22') do |m|
        m.element('resource_id', 'test')
        m.element('resource_address', 'test')
        PROP_ELEMENTS.each do |prop_element|
          m.property(prop_element) do |p|
            p.element('current', 'test')
            p.element('target', 'test')
          end
        end
      end
      inform.valid?.must_equal true
    end

    it "must return an event inform XML element without providing message context id" do
      inform = Message.inform('EVENT')
      inform.valid?.must_equal true
    end
  end

  describe "must be able to parse a XML element into Message object" do
    it "must behave" do
      xml = Message.create do |m|
        m.property('type', 'vm')
        m.property('os', 'debian')
        m.property('memory', 1024) do |p|
          p.element('unit', 'mb')
          p.element('precision', '0')
        end
      end.to_xml

      message = Message.parse(xml)

      message.must_be_kind_of Message
      message.operation.must_equal :create
      message.read_element("//property").size.must_equal 3
      message.read_content("unit").must_equal 'mb'
      message.read_element("/create/property").size.must_equal 3
      message.read_property("type").must_equal 'vm'
      message.read_property(:type).must_equal 'vm'
      memory = message.read_property(:memory)
      memory.must_be_kind_of Hashie::Mash
      memory.value.must_equal 1024
      memory.unit.must_equal 'mb'
      memory.precision.must_equal 0
    end
  end
end
