$:.unshift((d= File.dirname(__FILE__)) + '/../ruby')

require 'rubygems'
require 'test/unit'
require 'omf-common/oml/arel_remote'


class TestArelClient < Test::Unit::TestCase
  
  def setup
    return if @setup_done
      
    @setup_done = true
  end
  
  def test_xml()
    s2 = %{
      <repository>
        <name>test</name>
        <query>
          <table tname='iperf_TCP_Info'/>
          <project>
            <arg>
              <col name='oml_sender_id' table='iperf_TCP_Info'/>
            </arg>
            <arg type='string'>oml_ts_server</arg>
            <arg type='string'>Bandwidth_avg</arg>
          </project>
          <where>
            <arg>
              <col name='oml_sender_id' table='iperf_TCP_Info'/>
              <eq>
                <arg type='decimal'> 2</arg>
              </eq>
            </arg>
          </where>
        </query>
      </repository>
    }
    setup
    t1 = OMF::Common::OML::Arel::Table[:foo]
#    puts t1.to_xml
#  t1[:c1]
#  puts t1.project(:c1, :c2).each
#  puts t1.project(t1[:c1], t1[:c2]).each
#  puts t1.as(:tB).project(t1[:c1].as(:cA), t1.as(:tA)[:c2]).each
#  puts t1.project(:c1).where(t1[:c1].eq(Time.now)).each
#  puts "Done"
    
#    assert_equal [2, 1.762236, 0.0], res
  end
  
end
