require 'test_helper'
require 'omf_ec/experiment_property'
require 'omf_ec/dsl'
include OmfEc::DSL

describe OmfEc::ExperimentProperty do

  describe "when a new ExperimentProperty is created" do
    it "must raise an error if it is given an invalid name" do
      created_properties = 0
      # Test only a few common invalid name patterns
      %w(12 a=b a/b 1a .a a.b a?b a!b !a ?a #a $a @a %a).each do |name|
        begin
          OmfEc::ExperimentProperty.create(name)
          created_properties = created_properties + 1
        rescue Exception => ex
          ex.must_be_kind_of OEDLCommandException
        end
      end
      created_properties.must_equal 0
    end

    it "must not create a new property if one already exist with the same name" do
      size_before = OmfEc::ExperimentProperty.length
      OmfEc::ExperimentProperty.create('bar','a')
      OmfEc::ExperimentProperty[:bar].value.must_equal 'a'
      OmfEc::ExperimentProperty.create('bar','b')
      OmfEc::ExperimentProperty[:bar].value.must_equal 'b'
      OmfEc::ExperimentProperty.length.must_equal (size_before + 1)
    end

    it "must return a properly set ExperimentProperty object" do
      size_before = OmfEc::ExperimentProperty.length
      OmfEc::ExperimentProperty.create('foo', 1, 'abc')
      OmfEc::ExperimentProperty[:foo].name.must_equal 'foo'
      OmfEc::ExperimentProperty[:foo].value.must_equal 1
      OmfEc::ExperimentProperty[:foo].description.must_equal 'abc'
      OmfEc::ExperimentProperty.length.must_equal (size_before + 1)
    end

    it "must inform all of its observers when its value changes" do
      value = 2
      foobar = OmfEc::ExperimentProperty.create('foobar',1)
      foobar.on_change { |v| v.must_equal value } 
      foobar.on_change { |v| (v*2).must_equal value*2 }
      OmfEc::ExperimentProperty[:foobar] = value
      OmfEc::ExperimentProperty[:foobar].value.must_equal value
    end
  end

  describe "when a the Class ExperimentProperty is creating a new property" do
    it "must inform all of its observers" do
      size_before = OmfEc::ExperimentProperty.length
      OmfEc::ExperimentProperty.add_observer do |c,p|
        p.name.must_equal 'barfoo'
        p.value.must_equal 123
        p.description.must_equal 'abc'
      end
      OmfEc::ExperimentProperty.create('barfoo', 123, 'abc')
      OmfEc::ExperimentProperty.length.must_equal (size_before + 1)
    end
  end

  describe "when an operation involves an ExperimentProperty" do
    it "must return the expected result" do
      OmfEc::ExperimentProperty[:foo] = 2
      (OmfEc::ExperimentProperty[:foo] + 1).must_equal 3
      (1 + OmfEc::ExperimentProperty[:foo]).must_equal 3
      (OmfEc::ExperimentProperty[:foo] - 1).must_equal 1
      (1 - OmfEc::ExperimentProperty[:foo]).must_equal -1
      (OmfEc::ExperimentProperty[:foo] * 2).must_equal 4      
      (2 * OmfEc::ExperimentProperty[:foo]).must_equal 4
      (OmfEc::ExperimentProperty[:foo] / 1).must_equal 2      
      (2 / OmfEc::ExperimentProperty[:foo]).must_equal 1
      OmfEc::ExperimentProperty[:bar] = 'a'
      (OmfEc::ExperimentProperty[:bar] + "b").must_equal 'ab'     
      ('b' + OmfEc::ExperimentProperty[:bar]).must_equal 'ba'    
    end
  end

end
