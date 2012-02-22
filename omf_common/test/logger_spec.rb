require 'minitest/autorun'
require 'minitest/pride'
require 'omf_common/logger'

describe OmfCommon::Logger do
  describe "when used to log message" do
    it "must print a proper log message" do
      Proc.new do
        OmfCommon::Logger.instance.logger.debug 'DEBUG MESSAGE'
      end.must_output "#{Time.now.to_s} [DEBUG] DEBUG MESSAGE\n"
    end
  end
end
