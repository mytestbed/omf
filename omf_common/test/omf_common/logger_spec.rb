require 'test_helper'
require 'omf_common/logger'

describe OmfCommon::Logger do
  describe "when used to log message" do
    it "must print a proper log message" do
      stdout, stderr = capture_io do
        OmfCommon::Logger.instance.logger.debug 'DEBUG MESSAGE'
      end
      stdout.must_match /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \+\d{4} \[DEBUG\] DEBUG MESSAGE/
    end
  end
end
