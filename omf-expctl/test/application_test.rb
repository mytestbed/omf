$:.unshift((d= File.dirname(__FILE__)) + '/../ruby').unshift(d + '/../../omf-common/ruby')

require 'test/unit'
require 'omf-expctl/appDefinition.rb'
require 'omf-expctl/application.rb'
require 'omf-expctl/oconfig.rb'


class MockNodeSet
  attr_reader :appCtxt, :send_str
  
  def addApplication(app)
    @appCtxt = app
  end
  
  def send(*args)
    @send_str = args.join('#')
  end
  
  def groupName()
    'mock'
  end

end

class TestApplication < Test::Unit::TestCase
  
  def define_test_app
    AppDefinition.reset()
    defApplication('test') do |a|
      a.path = '/bin/test'
    end
  end
  
  def test_create_unknown_app
    opts = {'default' => {'repository' => {'path' => ['.']}, 'communicator' => {'type' => 'mock'}}}
    OConfig.init(opts, 'foo')

    assert_raise IOError do
      Application.new('foo')
    end
  end

  def test_create_known_app
    define_test_app
    app = Application.new('test')
    assert_instance_of Application, app
  end
  
  def test_instantiate_app
    define_test_app
    ns = MockNodeSet.new
    app = Application.new('test')
    app.instantiate(ns, [])
    assert_equal ns.appCtxt.app, app
  end

  def test_start_app
    define_test_app
    ns = MockNodeSet.new
    app = Application.new('test')
    app.instantiate(ns, [])
    ns.appCtxt.startApplication(ns)
    assert_equal ['exec', 'test', 'env', '-i', '/bin/test'].join('#'), ns.send_str
  end

  def test_param_mandatory
    AppDefinition.reset()
    ex = assert_raise(OEDLMissingArgumentException) do
      defApplication('t1') do |a|
        a.defProperty()
      end
    end
    assert_equal :name, ex.argName
    
    ex = assert_raise(OEDLMissingArgumentException) do
      defApplication('t2') do |a|
        a.defProperty('a')
      end
    end
    assert_equal :description, ex.argName

    ex = assert_raise(OEDLIllegalArgumentException) do
      defApplication('t3') do |a|
        a.defProperty('p1', 'x', :type => :int)
      end
    end
    assert_equal :mnemonic, ex.argName
  end 
  
  def test_param_int
    AppDefinition.reset()
    defApplication('t1') do |a|
      a.defProperty('p1', 'no comment', 'p', :type => :int)
      a.path = '/bin/t1'
    end
    ad = AppDefinition['t1']
    p = ad.properties['p1']
    
    assert_not_nil p
    assert_equal :int, p.type

    app = Application.new('t1')
    app.setProperty('p1', 9)
    
    ns = MockNodeSet.new
    app.instantiate(ns)
    assert_not_nil ns.appCtxt
    
    ns.appCtxt.startApplication(ns)
    assert_equal ['exec', 't1', 'env', '-i', '/bin/t1', '-p', '9'].join('#'), ns.send_str
    
  end
end
