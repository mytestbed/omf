# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_ec/dsl'

describe OmfEc::DSL do
  before do
    OmfCommon::Eventloop.init(type: :em)
    @dsl = Class.new { include OmfEc::DSL }.new
    OmfEc.stubs(:subscribe_and_monitor)
  end

  after do
    OmfCommon::Eventloop.reset
    OmfEc::Experiment.reset
    OmfEc::ExperimentProperty.reset
    OmfEc.unstub(:subscribe_and_monitor)
  end

  describe "when calling defGroup" do
    it "must be able to accept a list of arguments" do
      @dsl.defGroup('bob', 'a', 'b') do |g|
        g.members.keys.must_include 'a'
        g.members.keys.must_include 'b'
        g.must_be_kind_of OmfEc::Group
      end
    end

    it "must be able to accept array as arguments" do
      array = %w(c d)
      @dsl.defGroup('bob', array) do |g|
        g.members.keys.must_include 'c'
        g.members.keys.must_include 'd'
        g.must_be_kind_of OmfEc::Group
      end
    end
  end

  describe "when included" do
    it "must respond to after and every" do
      EM.run { @dsl.after(0.01) { EM.stop } }
      EM.run { @dsl.every(0.01) { EM.stop } }
    end

    it "must define property correctly" do
      @dsl.def_property('name', 'default', 'testing')
      @dsl.property.must_equal OmfEc::ExperimentProperty
      OmfEc::ExperimentProperty.reset
    end

    it "must respond to def_application" do
      block = proc { 1 }
      @dsl.def_application('bob', &block).must_equal 1
      OmfEc.experiment.app_definitions.key?('bob').must_equal true
    end

    it "must respond to group" do
      lambda { @dsl.group('bob') }.must_raise RuntimeError
      g = mock
      OmfEc.experiment.stubs(:group).returns(g)
      @dsl.group('bob').must_equal g
    end

    it "must respond to all_groups iterator" do
      block = proc { 1 }
      @dsl.all_groups(&block)
    end

    it "must respond to all_groups?" do
      OmfEc.experiment.stub :groups, [] do
        @dsl.all_groups? { true }.must_equal false
      end
      @dsl.def_group('bob')
      @dsl.all_groups? { |g| g.name == 'bob' }.must_equal true
    end

    it "must respond to all_equal" do
      @dsl.all_equal([]).must_equal false
      @dsl.all_equal([1, 1], 1).must_equal true
      @dsl.all_equal([1, 1]) do |v|
        v == 1
      end.must_equal true
    end

    it "must respond to one_equal" do
      @dsl.one_equal([1, 0], 1).must_equal true
      @dsl.one_equal([0, 0], 1).must_equal false
    end

    it "must init OEDL exceptions" do
      lambda { raise OEDLArgumentException.new("ls", "bob") }.must_raise OEDLArgumentException
      lambda { raise OEDLCommandException.new("bob") }.must_raise OEDLCommandException
      lambda { raise OEDLUnknownProperty.new("bob") }.must_raise OEDLUnknownProperty
    end

    it "must respond to done!" do
      done!
    end

    it "must respond to define an event" do
      lambda { def_event :bob }.must_raise ArgumentError

      def_event(:bob) { nil }
    end

    it "must respond to event callback" do
      lambda { on_event(:bob) }.must_raise RuntimeError
      def_event(:bob) { nil }
      on_event(:bob) { nil }
    end

    describe "when using OEDL 5 syntax" do
      it "must respond to wait" do
        @dsl.wait(0.01)
      end

      it "must respond to defApplication" do
        @dsl.defApplication('some_uri')
      end

      it "must respond to defGroup" do
        @dsl.defGroup('bob', 'a', 'b') { nil }
      end
    end
  end
end
