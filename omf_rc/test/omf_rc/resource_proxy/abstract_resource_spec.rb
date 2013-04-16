require 'test_helper'
require 'em/minitest/spec'
require 'omf_rc/resource_factory'
require 'blather'

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
    @xmpp = MiniTest::Mock.new
    @xmpp.expect(:subscribe, true, [String])
    OmfCommon.stub :comm, @xmpp do
      @node = OmfRc::ResourceFactory.new(:node, { hrn: 'default_node' }, { create_children_resources: true })
    end
  end

  describe "when intialised" do
    it "must convert configuration hash into instance methods, and assign the values" do
      @node.type.must_equal :node
    end

    it "must have an unique id generated" do
      @node.uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
      @node.request_uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
    end

    it "could keep state inside 'property' instnace variable" do
      @node.property.bob = "test"
      @node.property.bob.must_equal "test"
    end

    it "must be able to access creation options" do
      @node.creation_opts[:create_children_resources].must_equal true
    end
  end

  describe "when asked to create another resource" do
    it "must return the newly created resource" do
      OmfCommon.stub :comm, @xmpp do
        @xmpp.expect(:subscribe, true, [String])
        @node.create(:interface).must_be_kind_of AbstractResource
      end
    end

    it "must add the resource to its created resource list" do
      OmfCommon.stub :comm, @xmpp do
        @xmpp.expect(:subscribe, true, [String])
        child = @node.create(:wifi, { hrn: 'default_wifi' })
        @node.children.must_include child
        @node.request_child_resources.find { |v| v.uid == child.uid }.name.must_equal 'default_wifi'
      end
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      skip
      OmfCommon.stub :comm, @xmpp do
        @xmpp.expect(:delete_topic, nil)
        @xmpp.expect(:subscribe, true, [String])
        child = @node.create(:wifi, { hrn: 'default_wifi' })
        @node.children.wont_be_empty
        @node.release(child.uid)
        @node.children.must_be_empty
      end
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
    #include EM::MiniTest::Spec

    before do
      #@client = Blather::Client.new
      #@stream = MiniTest::Mock.new
      #@stream.expect(:send, true, [Blather::Stanza])
      #@client.post_init @stream, Blather::JID.new('n@d/r')
      #@xmpp = OmfCommon::Comm::XMPP::Communicator.new
    end

    it "must be able to send inform message" do
      skip
      # FIXME
      @xmpp.stub :publish, proc { |replyto, message| message.valid?.must_equal true} do
        @node.inform(:creation_ok, res_id: 'bob', cid: 'id', replyto: 'topic')
        @node.inform(:released, res_id: 'bob', cid: 'id', replyto: 'topic')
        @node.inform(:status, status: { key: 'value' }, cid: 'id', replyto: 'topic')
        @node.inform(:creation_ok, res_id: 'bob', cid: 'id', replyto: 'topic')
        @node.inform(:warn, 'going to fail')
        @node.inform(:error, 'failed')
        @node.inform(:warn, Exception.new('going to fail'))
        @node.inform(:error, Exception.new('failed'))
        @node.inform(:creation_failed, Exception.new('failed'))
      end

      lambda { @node.inform(:creation_failed, 'bob') }.must_raise ArgumentError
      lambda { @node.inform(:creation_ok, 'topic') }.must_raise ArgumentError
      lambda { @node.inform(:status, 'topic') }.must_raise ArgumentError
    end

    it "must be able to connect & disconnect" do
      skip
      Blather::Client.stub :new, @client do
        Blather::Stream::Client.stub(:start, @client) do
          @node = OmfRc::ResourceFactory.new(:node, { hrn: 'default_node', user: 'bob', password: 'pw', server: 'example.com'}, @xmpp)
          @client.stub(:connected?, true) do
            @node.connect
            @node.comm.conn_info.must_equal({proto: :xmpp, user: 'bob', doamin: 'example.com'})
          end
        end
      end
    end
  end

  describe "when request/configure property not pre-defined in proxy" do
    it "must try property hash" do
      skip
      @node.property[:bob] = "bob"
      @node.property[:false] = false

      @node.methods.must_include :request_bob
      @node.methods.must_include :configure_bob

      @node.request_bob.must_equal "bob"
      @node.request_false.must_equal false

      @node.configure_bob("not_bob")
      @node.request_bob.must_equal "not_bob"
      proc { @node.request_bobs_cousin }.must_raise OmfRc::UnknownPropertyError
      proc { @node.bobs_cousin }.must_raise NoMethodError
    end
  end
end
