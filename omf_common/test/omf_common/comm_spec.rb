# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_common/comm/local/local_communicator'

describe OmfCommon::Comm do
  describe "when initialised without providing a pubsub implementation" do
    before do
      OmfCommon::Comm.any_instance.stubs(:on_connected)
      @abstract_comm = OmfCommon::Comm.new(bob: nil)
      @topic = mock
    end

    it "must raise no implementation error for abstract methods" do
      OmfCommon::Comm.any_instance.unstub(:on_connected)
      [:disconnect, :on_connected, :on_connected].each do |m|
        lambda { @abstract_comm.send(m, ) }.must_raise NotImplementedError
      end

      [:create_topic, :delete_topic].each do |m|
        lambda { @abstract_comm.send(m, :bob) }.must_raise NotImplementedError
      end
    end

    it "must return options" do
      @abstract_comm.options.must_equal(bob: nil)
    end

    it "must return connection info" do
      @abstract_comm.conn_info.must_equal({ proto: nil, user: nil, domain: nil })
    end

    it "must be able to subscribe to a topic" do
      @abstract_comm.stubs(:create_topic).returns(@topic)
      @topic.expects(:on_subscribed)
      @abstract_comm.subscribe(:bob) { 'do nothing' }
    end
  end

  describe 'when initialised with a pubsub implementation' do
    after do
      OmfCommon::Comm.reset
    end

    it 'must fail if you throw in rubbish options' do
      lambda { OmfCommon::Comm.init(bob: nil) }.must_raise ArgumentError
      lambda { OmfCommon::Comm.init(provider: {}) }.must_raise ArgumentError
      lambda { OmfCommon::Comm.init(provider: { constructor: {}, require: {} }) }.must_raise TypeError
    end

    it 'wont fail if already initialised' do
      OmfCommon::Comm::Local::Communicator.any_instance.stubs(:on_connected)
      OmfCommon::Message.stubs(:init)

      OmfCommon::Comm.init(type: :local)
      OmfCommon::Comm.init(type: :local)
    end

    it 'must handle auth options and be able to return singleton instance' do
      OmfCommon::Comm::Local::Communicator.any_instance.stubs(:on_connected)

      OmfCommon::Message.stubs(:init)
      OmfCommon::Auth::CertificateStore.stubs(:init)
      OmfCommon::Comm.init(type: :local, auth: {})

      OmfCommon::Comm.instance.must_be_kind_of OmfCommon::Comm::Local::Communicator
    end
  end
end
