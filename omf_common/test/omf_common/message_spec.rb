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
          m.property(prop_element, {min_value: 'test', max_value: 'test'})
        end
      end
      request.valid?.must_equal true
    end

    it "must return a release XML element without failing" do
      release = Message.release { |v| v.element('resource_id', 'test') }
      release.valid?.must_equal true
    end

    it "must return a inform XML element without failing" do
      inform = Message.inform('CREATED', '9012c3bc-68de-459a-ac9f-530cc7168e22') do |m|
        m.element('resource_id', 'test')
        m.element('resource_address', 'test')
        PROP_ELEMENTS.each do |prop_element|
          m.property(prop_element, { current: 'test', target: 'test'})
        end
      end
      inform.valid?.must_equal true
    end

    it "context_id & resource_id shortcut must work too" do
      m = Message.inform('CREATED', '9012c3bc-68de-459a-ac9f-530cc7168e22') do |m|
        m.element('resource_id', 'test')
      end
      m.resource_id.must_equal 'test'
      m.context_id.must_equal '9012c3bc-68de-459a-ac9f-530cc7168e22'
    end

    it "must escape erb code in property" do
      m = Message.inform('CREATED', '9012c3bc-68de-459a-ac9f-530cc7168e22') do |m|
        m.property('bob', "hello <%= world %>")
        m.property('alice', "hello <%= 1 % 2 %>")
      end
      m.read_property('bob').must_equal "hello <%= world %>"
      world = 'world'
      m.read_property('bob', binding).must_equal "hello world"
      m.read_property('alice', binding).must_equal "hello 1"
    end

    it "must be able to pretty print an app_event message" do
      Message.inform('STATUS') do |m|
        m.property('status_type', 'APP_EVENT')
        m.property('event', 'DONE.OK')
        m.property('app', 'app100')
        m.property('msg', 'Everything will be OK')
        m.property('seq', 1)
      end.print_app_event.must_equal "APP_EVENT (app100, #1, DONE.OK): Everything will be OK"
    end
  end

  describe "when asked to parse a XML element into Message object" do
    it "must create the message object correctly " do
      xml = Message.create do |m|
        m.property('type', 'vm')
        m.property('os', 'debian')
        m.property('memory', { value: 1024, unit: 'mb', precision: 0 })
        m.property('devices', [{ name: 'w0', driver: 'mod_bob'}, { name: 'w1', driver: ['mod1', 'mod2']} ])
        m.property('true', true)
        m.property('false', false)
        m.property('boolean_array', [false, true])
      end.canonicalize

      message = Message.parse(xml)

      message.must_be_kind_of Message
      message.operation.must_equal :create
      message.read_element("//property").size.must_equal 7
      message.read_content("unit").must_equal 'mb'
      message.read_element("/create/property").size.must_equal 7
      message.read_property("type").must_equal 'vm'
      message.read_property(:type).must_equal 'vm'

      memory = message.read_property(:memory)
      memory.must_be_kind_of Hashie::Mash
      memory.value.must_equal 1024
      memory.unit.must_equal 'mb'
      memory.precision.must_equal 0

      devices = message.read_property(:devices)
      devices.must_be_kind_of Array
      devices.size.must_equal 2
      devices.find { |v| v.name == 'w1'}.driver.size.must_equal 2
      # Each property iterator
      message.each_property do |v|
        %w(type os memory devices true false boolean_array).must_include v.attr('key')
      end

      message.read_property(:true).must_equal true
      message.read_property(:false).must_equal false
      message.read_property('boolean_array').must_equal [false, true]
    end

    it "must fail if parse an empty xml" do
      lambda { Message.parse("") }.must_raise ArgumentError
      lambda { Message.parse(nil) }.must_raise ArgumentError
    end
  end

  describe "when query the message object" do
    it "must return nil if content of a property is empty string" do
      xml = Message.request do |m|
        m.property('type', 'vm')
        m.property('empty')
        m.element('empty')
      end

      xml.read_property('type').must_equal 'vm'
      xml.read_property('empty').must_equal nil
      xml.read_content('empty').must_equal nil
    end
  end
end
