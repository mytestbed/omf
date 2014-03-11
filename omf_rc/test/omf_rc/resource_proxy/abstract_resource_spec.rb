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

    property :p0
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
    mock_comm_in_res_proxy
    mock_topics_in_res_proxy(resources: [:parent, :child], default: :child)
    @parent = OmfRc::ResourceFactory.create(:parent, { uid: :parent, hrn: 'default_node' }, { create_children_resources: true })
  end

  after do
    unmock_comm_in_res_proxy
    @parent = nil
  end

  describe "when created itself (bootstrap)" do
    it "must have an unique id generated if not given" do
      OmfRc::ResourceFactory.create(:parent).uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
    end

    it "must be able to initialise properties" do
      p = OmfRc::ResourceFactory.create(:parent, { p0: 'bob', uid: 'unique' })
      p.request_p0.must_equal 'bob'
      p.request_uid.must_equal 'unique'
    end

    it "must be able to keep state inside 'property' instnace variable" do
      @parent.property.bob = "test"
      @parent.property.bob.must_equal "test"
    end

    it "must be able to access creation options" do
      @parent.creation_opts[:create_children_resources].must_equal true
    end

    it "must returned all the properties can be requested & configured" do
      @parent.request_available_properties.configure.must_equal [:p0, :membership, :res_index]
      @parent.request_available_properties.request.must_equal(
        [:p0, :test_exception, :supported_children_type, :uid, :type, :hrn, :name, :membership, :res_index, :child_resources]
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
      @parent.configure_membership([:test_group, 'test_group_2'])
      @parent.request_membership.must_include :test_group
      @parent.request_membership.must_include 'test_group_2'
    end

    it "must be able to configure membership (leave group)" do
      @parent.configure_membership([:test_group, 'test_group_2'])
      @parent.configure_membership({ leave: [:test_group] })
      @parent.request_membership.must_equal ['test_group_2']
      @parent.configure_membership({ leave: [:test_group, 'test_group_2'] })
      @parent.request_membership.must_equal []
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
    it "must be able to send inform message" do
      @parent.inform(:creation_ok, res_id: 'bob')
      @parent.inform(:released, res_id: 'bob')

      @parent.inform_status(key: 'value')
      @parent.inform_warn('going to fail')
      @parent.inform_error('failed')
      @parent.inform_creation_failed('failed')
    end
  end

  describe "when request/configure property not pre-defined in proxy (adhoc)" do
    it "must try property hash for internal usage" do
      @parent.property[:bob] = "bob"
      @parent.property[:boolean] = false
      @parent.property.bob.must_equal "bob"
      @parent.property.boolean.must_equal false
    end

    it "wont create request/configure method for such property" do
      @parent.methods.wont_include :request_bob
      @parent.methods.wont_include :configure_bob
      proc { @parent.request_bob }.must_raise NoMethodError
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

    it "must rescue exception if occurred" do
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
