FIXTURE_DIR = "#{File.dirname(__FILE__)}/fixture"

OmfCommon::Command = MiniTest::Mock.new

def mock_execute(result, command_pattern)
  OmfCommon::Command.expect :execute, result, [command_pattern]
end

def mock_verify_execute
  OmfCommon::Command.verify
end

def fixture(name)
  File.read("#{FIXTURE_DIR}/#{name.to_s}")
end
