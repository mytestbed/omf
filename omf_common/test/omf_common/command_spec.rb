require 'test_helper'
require 'omf_common/command'

describe OmfCommon::Command do
  describe "when use util file to execute a system command" do
    it "must not print anything to stdout if executed successfully" do
      OmfCommon::Command.execute("date").must_match /^.+/
    end

    it "must capture and log errors if command not found" do
      OmfCommon::Command.execute("dte -z").must_be_nil
    end
  end
end
