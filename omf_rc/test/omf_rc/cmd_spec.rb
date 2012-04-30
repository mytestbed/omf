require 'test_helper'
require 'em/minitest/spec'
require 'omf_rc/cmd'

describe OmfRc::Cmd do
  describe "when use util file to execute a system command" do
    include EM::MiniTest::Spec

    it "must return result and not print anything to stdout if executed successfully" do
      EM.reactor_running?.must_equal true
      OmfRc::Cmd.exec("ls") do |output, status|
        output.wont_be_nil
        status.exitstatus.must_equal 0
      end
    end
  end
end
