require 'test_helper'
require 'omf_ec/dsl'

describe OmfEc::DSL do
  describe "when included" do

    include OmfEc::DSL

    it "must respond to after and every" do
      respond_to?(:after).must_equal true
      respond_to?(:every).must_equal true
    end

    it "must respond to def_property" do
      def_property('name', 'default', 'testing')
    end

    it "must respond to def_application" do
      block = proc { 1 }
      def_application('bob', &block).must_equal 1
      OmfEc.experiment.app_definitions.key?('bob').must_equal true
    end

    it "must respond to def_group" do
      block = proc { 1 }
      OmfEc.stub :subscribe_and_monitor, true do
        def_group('bob', &block).must_be_kind_of OmfEc::Group
      end
    end

    it "must respond to all_groups iterator" do
      block = proc { 1 }
      all_groups(&block)
    end

    it "must respond to all_groups?" do
      OmfEc.stub :subscribe_and_monitor, true do
        OmfEc.experiment.stub :groups, [] do
          all_groups? { true }.must_equal false
        end
        def_group('bob')
        all_groups? { |g| g.name == 'bob' }.must_equal true
      end
    end
  end

end

