require 'test_helper'
require 'omf_rc/cmd'

describe OmfRc::Cmd do
  describe "when use util file to execute a system command" do
    it "must return result and not print anything to stdout if executed successfully" do
      OmfRc::Cmd.exec("ls").wont_be_empty
      proc { OmfRc::Cmd.exec("ls") }.must_be_silent
    end
  end
end
