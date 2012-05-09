require 'test_helper'
require 'em/minitest/spec'
require 'omf_rc/cmd'

describe OmfRc::Cmd do
  describe "when use util file to execute a system command" do
    include EM::MiniTest::Spec

    it "must return result eventually" do
      OmfRc::Cmd.exec("uname -a") do |result|
        result[:success].wont_be_empty
        done!
      end
      wait!
    end
  end
end
