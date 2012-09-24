require 'test_helper'
require 'em/minitest/spec'
require 'omf_rc/resource_factory'

include OmfRc::ResourceProxy

module OmfRc::ResourceProxy
  module Node
    include OmfRc::ResourceProxyDSL
    register_proxy :node

    request :name
    configure :name
  end

  module Interface
    include OmfRc::ResourceProxyDSL
    register_proxy :interface
  end

  module Wifi
    include OmfRc::ResourceProxyDSL
    register_proxy :wifi
  end

  module Mock
    include OmfRc::ResourceProxyDSL
    register_proxy :mock
  end
end

describe AbstractResource do
  before do
    @node = OmfRc::ResourceFactory.new(:node, { hrn: 'default_node' })
  end

  describe "when intialised" do
    it "must convert configuration hash into instance methods, and assign the values" do
      @node.type.must_equal 'node'
    end

    it "must have an unique id generated" do
      @node.uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
      @node.request_uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
    end

    it "could keep state inside 'property' instnace variable" do
      @node.property.bob = "test"
      @node.property.bob.must_equal "test"
    end
  end

  describe "when asked to create another resource" do
    it "must return the newly created resource" do
      @node.create(:interface).must_be_kind_of AbstractResource
    end

    it "must add the resource to its created resource list" do
      child = @node.create(:wifi, { hrn: 'default_wifi' })
      @node.children.must_include child
      @node.request_child_resources[child.uid].must_equal 'default_wifi'
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      child = @node.create(:wifi, { hrn: 'default_wifi' })
      @node.children.wont_be_empty
      @node.release(child.uid)
      @node.children.must_be_empty
    end
  end

  describe "when asked for the funcitonalities it supports" do
    it "must returned all the properties can be requested & configured" do
      @node.request_available_properties.must_be_kind_of Hashie::Mash
      @node.request_available_properties.configure.must_include :name
      @node.request_available_properties.request.must_include :name
    end

    it "must be able to request and configure some common properties" do
      @node.request_hrn.must_equal 'default_node'
      @node.configure_hrn('bob')
      @node.request_hrn.must_equal 'bob'
    end
  end

  describe "when interacted with communication layer" do
    include EM::MiniTest::Spec

    before do
      @client = Blather::Client.new
      @stream = MiniTest::Mock.new
      @stream.expect(:send, true, [Blather::Stanza])
      @client.post_init @stream, Blather::JID.new('n@d/r')
      @xmpp = Class.new { include OmfCommon::DSL::Xmpp }.new
    end

    it "must be able to send inform message" do
      @node.comm.stub :publish, proc { |inform_to, message| message.valid?.must_equal true} do
        @node.inform(:created, resource_id: 'bob', context_id: 'id', inform_to: 'topic')
        @node.inform(:released, resource_id: 'bob', context_id: 'id', inform_to: 'topic')
        @node.inform(:status, status: { key: 'value' }, context_id: 'id', inform_to: 'topic')
        @node.inform(:created, resource_id: 'bob', context_id: 'id', inform_to: 'topic')
        @node.inform(:warn, 'going to fail')
        @node.inform(:error, 'failed')
        @node.inform(:warn, Exception.new('going to fail'))
        @node.inform(:error, Exception.new('failed'))
      end

      lambda { @node.inform(:failed, 'bob') }.must_raise ArgumentError
      lambda { @node.inform(:created, 'topic') }.must_raise ArgumentError
      lambda { @node.inform(:status, 'topic') }.must_raise ArgumentError
    end

    it "must be able to connect & disconnect" do
      Blather::Client.stub :new, @client do
        Blather::Stream::Client.stub(:start, @client) do
          @node = OmfRc::ResourceFactory.new(:node, { hrn: 'default_node', user: 'bob', password: 'pw', server: 'example.com'}, @xmpp)
          @client.stub(:connected?, true) do
            @node.connect
            @node.comm.jid.inspect.must_equal "bob@example.com"
          end
        end
      end
    end
  end

  describe "when request/configure property not pre-defined in proxy" do
    it "must try property hash" do
      @node.property[:bob] = "bob"
      @node.request_bob.must_equal "bob"
      @node.configure_bob("not_bob")
      @node.request_bob.must_equal "not_bob"
      proc { @node.request_bobs_cousin }.must_raise NoMethodError
      proc { @node.bobs_cousin }.must_raise NoMethodError
    end
  end
end
