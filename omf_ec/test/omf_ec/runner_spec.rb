require 'test_helper'
require 'omf_ec/runner'

describe OmfEc::Runner do
  before do
    uninit
  end

  after do
    uninit
  end
  it "must allow to accept a set of command line options" do
    ARGV.clear
    "-u amqp://localhost --slice empty --oml_uri tcp:localhost:3003 -e xxx -d --experiment e1 --show-graph exec #{File.dirname(__FILE__)}/../oedls/empty.oedl -- --prop_1 p1value".split(" ").each do |opt|
      ARGV << opt
    end
    runner = OmfEc::Runner.new
    runner.init

    assert_equal 'e1', OmfEc.experiment.name
    assert_equal "tcp:localhost:3003", OmfEc.experiment.oml_uri
    assert_equal true, OmfEc.experiment.show_graph
    assert_match /oedls\/empty.oedl/, runner.oedl_path
  end
end
