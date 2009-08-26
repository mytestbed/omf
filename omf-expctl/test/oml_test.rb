$:.unshift((d= File.dirname(__FILE__)) + '/../ruby').unshift(d + '/../../omf-common/ruby')

require 'test/unit'
require 'rubygems'
require 'omf-expctl/handlerCommands.rb'
require 'omf-expctl/appDefinition.rb'
require 'omf-expctl/application.rb'
require 'omf-expctl/oconfig.rb'
require 'omf-expctl/nodeSet.rb'


class MockNodeSet
  attr_reader :appCtxt, :send_str
  
  def addApplication(app)
    @appCtxt = app
  end
  
  def send(*args)
    @send_str = args.join('::')
  end
end

class TestOML < Test::Unit::TestCase
  def test_def_measure_no_block
    AppDefinition.reset()
    defApplication("oml") do |a|
      a.defMeasurement('m1')
    end
  end

  def test_def_measure_metric_missing_args
    AppDefinition.reset()
    defApplication("oml") do |a|
      a.defMeasurement('mp') do |m|
        begin 
          m.defMetric()
        rescue Exception => ex
          assert_instance_of OEDLMissingArgumentException, ex
          assert_equal :name, ex.argName
        end
        begin 
          m.defMetric('foo')
        rescue Exception => ex
          assert_instance_of OEDLMissingArgumentException, ex
          assert_equal :type, ex.argName
        end
      end
    end
  end
  
  def test_start_app_no_metric
    init_communicator()
    AppDefinition.reset()
    defApplication('oml') do |a|
      a.defMeasurement('mp') do |m|
        m.defMetric('foo', :int)
      end
    end
    defGroup('g1') do |g|
      g.addApplication('oml')
    end
    group('g1').startApplications()
    assert_equal "g1|exec|oml#env#-i#", Communicator.instance.cmds[-1]
  end

  def test_start_app_metric
    init_communicator()
    TraceState.init()
    
    AppDefinition.reset()
    defApplication('oml') do |a|
      a.defMeasurement('mp') do |m|
        m.defMetric('foo', :int)
      end
    end
    defGroup('g2') do |g|
      g.addApplication('oml') do |a|
        a.measure('mp')
      end
    end
    group('g2').startApplications()
    assert_equal "g2|exec|oml#env#-i#", Communicator.instance.cmds[-1]
  end
  
  def init_communicator()
    OConfig.reset()
    opts = {'default' => {'repository' => {'path' => ['.']}, 'communicator' => {'type' => 'mock' }}}
    OConfig.init(opts, 'foo')
  end
  
end
