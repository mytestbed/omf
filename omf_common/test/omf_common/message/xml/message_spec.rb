# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_common/message/xml/message'

include OmfCommon

describe OmfCommon::Message::XML::Message do
  describe "when create message initialised" do
    before do
      @message = Message::XML::Message.create(:create,
                                              { type: 'bob', p1: 'p1_value', p2: { unit: 'u', precision: 2 } },
                                              { rtype: 'bob', guard: { p1: 'p1_value' } })
    end

    it "must to be validated using relaxng schema" do
      @message.valid?.must_equal true
    end

    it "must be able to be serialised as XML" do
      xml_payload = @message.marshall[1].to_xml
      xml_payload.must_match /^<create(.+)create>$/m
      xml_payload.must_match /<rtype>bob<\/rtype>/m
      xml_payload.must_match /<props(.+)props>/m
      xml_payload.must_match /<guard(.+)guard>/m
    end
  end

  describe "when release message initialised" do
    before do
      # We will test prop value other than just strings
      @message = Message::XML::Message.create(:release, {}, { res_id: 'bob', guard: { p1: 'p1_value' } })
    end

    it "must to be validated using relaxng schema" do
      @message.valid?.must_equal true
    end

    it "must be able to be serialised as XML" do
      xml_payload = @message.marshall[1].to_xml
      xml_payload.must_match /^<release(.+)release>$/m
      xml_payload.must_match /<res_id>bob<\/res_id>/m
      xml_payload.must_match /<guard(.+)guard>/m
    end
  end

  describe "when asked to parse a XML element into Message::XML::Message object" do
    before do
      @xml = Message::XML::Message.create(
        :create,
        { type: 'vm',
          os: 'debian',
          memory: { value: 1024, unit: 'mb', precision: 0 },
          devices: [{ name: 'w0', driver: 'mod_bob'}, { name: 'w1', driver: ['mod1', 'mod2']} ],
          true: true,
          false: false,
          empty: nil,
          boolean_array: [false, true] },
        { rtype: 'vm', guard: { os_type: 'linux' } }).marshall[1].to_xml

      Message::XML::Message.parse(@xml) { |v| @message = v }
    end

    it "must create the object correctly" do
      @message.must_be_kind_of Message::XML::Message
      @message.operation.must_equal :create
    end

    it "must provide normal xml xpath query" do
      @message.read_element("props").first.element_children.size.must_equal 8
      # TODO how to handle complext xpath??? with ns...
      # @message.read_content("//memory/unit").must_equal 'mb'
    end

    it "must provide unified message property access" do
      @message["type"].must_equal 'vm'
      @message[:type].must_equal 'vm'
    end

    it "must provide guard information" do
      @message.guard[:os_type].must_equal 'linux'
    end

    it "must be able reconstruct complicate data" do
      # Each property iterator
      @message.each_property do |k, v|
        %w(type os memory devices true false empty boolean_array).must_include k
      end

      memory = @message[:memory]
      memory.must_be_kind_of Hashie::Mash
      memory.value.must_equal 1024
      memory.unit.must_equal 'mb'
      memory.precision.must_equal 0

      devices = @message[:devices]
      devices.must_be_kind_of Array
      devices.size.must_equal 2
      devices.find { |v| v.name == 'w1'}.driver.size.must_equal 2
    end

    it "must be able ducktype string xml content for numbers, boolean, empty string" do
      @message[:true].must_equal true
      @message[:false].must_equal false
      @message[:boolean_array].must_equal [false, true]
      @message[:empty].must_equal nil
    end

    it "must fail if parse an empty xml" do
      lambda { Message::XML::Message.parse("") }.must_raise ArgumentError
      lambda { Message::XML::Message.parse(nil) }.must_raise ArgumentError
    end
  end

  describe "when creating request messages" do
    it "must accept an array of properties instead of hash" do
      request_m = Message::XML::Message.create(:request, [:p1, :p2])
      request_m.valid?.must_equal true
      request_m[:p1].must_be_nil
    end
  end

  describe "when parsing inform message" do
    it "must validate against inform message schema" do
      raw_xml = <<-XML
        <inform xmlns="http://schema.mytestbed.net/omf/6.0/protocol" mid="bob">
          <src>xmpp://bob@localhost</src>
          <ts>100</ts>
          <itype>CREATION.OK</itype>
        </inform>
      XML
      Message::XML::Message.parse(raw_xml) do |parsed_msg|
        parsed_msg.ts.must_equal "100"
        parsed_msg.itype.must_equal "CREATION.OK"

        parsed_msg.valid?.must_equal true
      end
    end
  end

  describe "when authentication enabled and certificate provided" do
    it "must generate an envelope for the message" do
      Message.stub(:authenticate?, true) do
        OmfCommon::Auth.init

        comm = mock
        topic = OmfCommon::Comm::Topic.create("bob_topic")
        topic.stubs(:address).returns('bob')
        OmfCommon.stubs(:comm).returns(comm)
        comm.expects(:create_topic).returns(topic)

        root_cert = OmfCommon::Auth::Certificate.create_root
        bob_cert = root_cert.create_for_resource('bob', :bob)

        message = Message::XML::Message.create(:create,
                                                { type: 'bob', p1: 'p1_value'},
                                                { rtype: 'bob', src: 'bob'})

        # m indicates multiple lines
        message.marshall[1].to_xml.must_match /<env(.+)env>/m
        message.valid?.must_equal true

        OmfCommon.comm.unstub(:comm)
      end
    end
  end
end
