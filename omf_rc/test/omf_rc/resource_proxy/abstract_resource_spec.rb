# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'em/minitest/spec'
require 'omf_rc/resource_factory'

include OmfRc::ResourceProxy

module OmfRc::ResourceProxy
  module Parent
    include OmfRc::ResourceProxyDSL
    register_proxy :parent

    request :test_exception do
      raise StandardError
    end
  end

  module Child
    include OmfRc::ResourceProxyDSL
    register_proxy :child, create_by: :parent
    property :p1
  end

  module RandomResource
    include OmfRc::ResourceProxyDSL
    register_proxy :random_resource, create_by: :nobody
  end
end

describe AbstractResource do
  before do
    # Things we need to mock
    # * communicator
    # * topic
    # * calling communicator callbacks
    @comm = mock
    @topics = {
      parent: OmfCommon::Comm::Topic.create(:parent),
      child:  OmfCommon::Comm::Topic.create(:child)
    }
    [:inform, :publish, :unsubscribe].each do |m_name|
      OmfCommon::Comm::Topic.any_instance.stubs(m_name)
    end

    # Return child topic by default unless specified
    @comm.stubs(:create_topic).returns(@topics[:child])

    [:parent, :child].each do |t_name|
      @topics[t_name].stubs(:address).returns("xmpp://localhost/#{t_name.to_s}")
      @comm.stubs(:create_topic).with("xmpp://localhost/#{t_name}").returns(@topics[t_name])
    end

    @comm.class_eval do
      define_method(:subscribe) do |*args, &block|
        block.call(self.create_topic("xmpp://localhost/#{args[0]}"))
      end
    end

    OmfCommon.stubs(:comm).returns(@comm)
    @parent = OmfRc::ResourceFactory.create(:parent, { uid: :parent, hrn: 'default_node' }, { create_children_resources: true })
  end

  after do
    @comm.class_eval do
      undef_method(:subscribe)
    end
    OmfCommon.unstub(:comm)
    [:inform, :publish, :unsubscribe].each do |m_name|
      OmfCommon::Comm::Topic.any_instance.unstub(m_name)
    end
    @parent = nil
  end

  describe "when created itself (bootstrap)" do
    it "must have an unique id generated if not given" do
      OmfRc::ResourceFactory.create(:parent).uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
    end

    it "must be able to keep state inside 'property' instnace variable" do
      @parent.property.bob = "test"
      @parent.property.bob.must_equal "test"
    end

    it "must be able to access creation options" do
      @parent.creation_opts[:create_children_resources].must_equal true
    end

    it "must returned all the properties can be requested & configured" do
      @parent.request_available_properties.configure.must_equal [:membership]
      @parent.request_available_properties.request.must_equal(
        [:test_exception, :supported_children_type, :uid, :type, :hrn, :name, :membership, :child_resources]
      )
    end

    it "must return types of child resources it can create" do
      @parent.request_supported_children_type.must_include :child
    end

    it "must be able to query core properties" do
      @parent.request_type.must_equal :parent
      @parent.request_name.must_equal 'default_node'
      @parent.request_hrn.must_equal 'default_node'
      @parent.request_membership.must_equal []
    end

    it "must be able to configure membership (join group)" do
      @parent.configure_membership(:test_group)
      @parent.request_membership.must_include :test_group
    end
  end

  describe "when parent asked to create child resource" do
    it "must return the newly created resource add the resource to its created resource list" do
      child = @parent.create(:child)
      @parent.children.must_include child
      @parent.request_child_resources.must_include({ uid: child.uid, address: child.resource_address })
    end

    it "must raise error if child is not designed to be created by parent" do
      lambda { @parent.create(:random_resource) }.must_raise StandardError
    end
  end

  describe "when parent asked to release child resource" do
    it "must release the child resource" do
      child = @parent.create(:child)
      @parent.release(child.uid).must_equal child
      @parent.children.must_be_empty
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
        @parent.inform(:creation_ok, res_id: 'bob', cid: 'id', replyto: 'topic')
        @parent.inform(:released, res_id: 'bob', cid: 'id', replyto: 'topic')
        @parent.inform(:status, status: { key: 'value' }, cid: 'id', replyto: 'topic')
        @parent.inform(:creation_ok, res_id: 'bob', cid: 'id', replyto: 'topic')
        @parent.inform(:warn, 'going to fail')
        @parent.inform(:error, 'failed')
        @parent.inform(:warn, Exception.new('going to fail'))
        @parent.inform(:error, Exception.new('failed'))
        @parent.inform(:creation_failed, Exception.new('failed'))
      end

      lambda { @parent.inform(:creation_failed, 'bob') }.must_raise ArgumentError
      lambda { @parent.inform(:creation_ok, 'topic') }.must_raise ArgumentError
      lambda { @parent.inform(:status, 'topic') }.must_raise ArgumentError
    end

    it "must be able to connect & disconnect" do
      skip
      Blather::Client.stub :new, @client do
        Blather::Stream::Client.stub(:start, @client) do
          @parent = OmfRc::ResourceFactory.create(:node, { hrn: 'default_node', user: 'bob', password: 'pw', server: 'example.com'}, @xmpp)
          @client.stub(:connected?, true) do
            @parent.connect
            @parent.comm.conn_info.must_equal({proto: :xmpp, user: 'bob', doamin: 'example.com'})
          end
        end
      end
    end
  end

  describe "when request/configure property not pre-defined in proxy" do
    it "must try property hash" do
      skip
      @parent.property[:bob] = "bob"
      @parent.property[:false] = false

      @parent.methods.must_include :request_bob
      @parent.methods.must_include :configure_bob

      @parent.request_bob.must_equal "bob"
      @parent.request_false.must_equal false

      @parent.configure_bob("not_bob")
      @parent.request_bob.must_equal "not_bob"
      proc { @parent.request_bobs_cousin }.must_raise OmfRc::UnknownPropertyError
      proc { @parent.bobs_cousin }.must_raise NoMethodError
    end
  end

  describe "when FRCP incoming messages received" do
    before do
      @create_msg = OmfCommon::Message.create(:create, { uid: 'child_001', type: :child, p1: 'p1_value' })
      @configure_msg = OmfCommon::Message.create(:configure, { p1: 'p1_value' })
      @request_msg = OmfCommon::Message.create(:request, { name: nil })
      @release_msg = OmfCommon::Message.create(:release, {}, { res_id: 'child_001' })
    end

    it "must accept FRCP messages" do
      @parent.process_omf_message(@request_msg, @topics[:parent])
    end

    it "must resuce exception if occured" do
      @parent.process_omf_message(OmfCommon::Message.create(:request, { test_exception: nil }), @topics[:parent])
    end

    it "must handle CREATE/RELEASE message" do
      @parent.handle_message(@create_msg, @parent)
      @parent.request_child_resources.must_include({ uid: 'child_001', address: 'xmpp://localhost/child' })

      @parent.handle_message(@release_msg, @parent)
      @parent.request_child_resources.wont_include({ uid: 'child_001', address: 'xmpp://localhost/child' })
    end

    it "must handle REQUEST message" do
      @parent.handle_message(@request_msg, @parent.create(:child))
    end

    it "must handle CONFIGURE message" do
      c = @parent.create(:child)
      @parent.handle_message(@configure_msg, c)
      c.request_p1.must_equal 'p1_value'
    end
  end
end
