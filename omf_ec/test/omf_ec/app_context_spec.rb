# Copyright (c) 2014 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_ec/context/app_context'

describe OmfEc::Context::AppContext do
  before do
    OmfEc.experiment.stubs(:app_definitions).returns({'foo_app' => 'foo_def'})
    @app_context = OmfEc::Context::AppContext.new('foo_app', 'foo_group')
  end

  describe "when defined with an associated application definition" do
    it "must be able to create valid configuration hash for OML Collection Measurement Points" do
      @app_context.measure('ms1', :samples => 1)
      @app_context.oml_collections.must_equal []
      @app_context.measure('ms1', :samples => 1, :collect => "foo1")
      @app_context.oml_collections.must_equal [{:url=>"foo1", :streams=>[{:mp=>"ms1", :filters=>[], :samples=>1}]}]
      @app_context.oml_collections = []
      @app_context.measure('ms1', :samples => 1, :collect => "foo1")
      @app_context.measure('ms2', :interval => 1, :collect => "foo1")
      @app_context.oml_collections.must_equal [{:url=>"foo1", :streams=>[{:mp=>"ms1", :filters=>[], :samples=>1}, {:mp=>"ms2", :filters=>[], :interval=>1}]}]
      @app_context.oml_collections = []
      @app_context.measure('ms1', :samples => 1, :collect => "foo1")
      @app_context.measure('ms2', :interval => 1, :collect => "foo2")
      @app_context.oml_collections.must_equal [{:url=>"foo1", :streams=>[{:mp=>"ms1", :filters=>[], :samples=>1}]}, {:url=>"foo2", :streams=>[{:mp=>"ms2", :filters=>[], :interval=>1}]}]
      OmfEc.experiment.stubs(:oml_uri).returns('foo_url')
      @app_context.oml_collections = []
      @app_context.measure('ms1', :samples => 1)
      @app_context.measure('ms2', :interval => 1)
      @app_context.oml_collections.must_equal [{:url=>"foo_url", :streams=>[{:mp=>"ms1", :filters=>[], :samples=>1}, {:mp=>"ms2", :filters=>[], :interval=>1}]}]
      @app_context.oml_collections = []
      @app_context.measure('ms1', :samples => 1)
      @app_context.measure('ms2', :interval => 1, :collect => "foo2")
      @app_context.oml_collections.must_equal [{:url=>"foo_url", :streams=>[{:mp=>"ms1", :filters=>[], :samples=>1}]}, {:url=>"foo2", :streams=>[{:mp=>"ms2", :filters=>[], :interval=>1}]}]
    end

  end
end
