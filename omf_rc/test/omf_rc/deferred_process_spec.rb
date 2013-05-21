# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'em/minitest/spec'
require 'omf_rc/deferred_process'

describe OmfRc::DeferredProcess do
  describe "when use to deferred process to execute code asynchronously" do
    include EM::MiniTest::Spec

    it "must execute and return result eventually, inside the EM loop" do
      dp = OmfRc::DeferredProcess.new

      dp.callback do |result|
        result.must_equal "hello world"
        done!
      end

      dp.fire do
        "hello world"
      end

      wait!
    end

    it "must capture errors properly inside the EM loop" do
      dp = OmfRc::DeferredProcess.new

      dp.errback do |exception|
        exception.must_be_kind_of StandardError
        done!
      end

      dp.fire do
        raise StandardError
      end

      wait!
    end
  end
end
