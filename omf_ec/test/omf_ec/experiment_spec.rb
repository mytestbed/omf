# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_ec/experiment'

describe OmfEc::Experiment do
  before do
    @experiment = OmfEc::Experiment.instance
  end

  it "must return id" do
    @experiment.id.wont_be_nil

    @experiment.name = 'bob'
    @experiment.id.must_match /bob-/
  end

  it "must be able to add event" do
    trigger = proc { 1 }
    @experiment.add_event('bob', trigger)
    @experiment.event('bob')[:name].must_equal "bob"
    @experiment.event('bob')[:trigger].call.must_equal 1
  end

  it "must be able to add sub group" do
    skip
    @experiment.add_sub_group('bob')
    @experiment.sub_group('bob').must_equal "bob"
  end

  it "must be able to add group" do
    proc { @experiment.add_group('bob') }.must_raise ArgumentError
    OmfEc.stub :subscribe_and_monitor, true do
      @experiment.add_group(OmfEc::Group.new('bob'))
      @experiment.group('bob').must_be_kind_of OmfEc::Group
    end
  end

  it "must be able to add resource to state" do
    @experiment.add_or_update_resource_state('bob', type: :test)
    @experiment.resource_state('bob')[:address].must_equal 'bob'
    @experiment.resource_state('bob')[:type].must_equal :test
  end
end
