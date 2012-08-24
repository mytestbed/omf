require 'test_helper'
require 'omf_common/command'

describe OmfCommon::Command do
  describe "when use util file to execute a system command" do
    it "must not print anything to stdout if executed successfully" do
      OmfCommon::Command.execute("ruby -e 'puts 100'").must_match /100/
    end

    it "must capture and log errors if command not found" do
      OmfCommon::Command.execute("blahblah -z").must_be_nil
    end

    it "must log error when exit status is not 0" do
      OmfCommon::Command.execute("ruby -e 'exit 1'").must_be_nil
      OmfCommon::Command.execute("ruby -e 'exit 2'").must_be_nil
      OmfCommon::Command.execute("ruby -e 'exit 3'").must_be_nil
    end
  end
end
