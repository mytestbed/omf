$:.unshift((d= File.dirname(__FILE__)) + '/../ruby')

require 'rubygems'
require 'test/unit'
require 'omf-common/oml/arel_server'
require 'active_record'


class TestArelServer < Test::Unit::TestCase
  
  def setup
    return if @setup_done
      
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    db_file = File.dirname(__FILE__) + '/test.sq3'
    db_config = {
      :adapter  => 'sqlite3',
      :database => db_file,
      :timeout  => 5000
    }
    #class DatabaseA < ActiveRecord::Base
    #  establish_connection $config['database1']
    #end
    ActiveRecord::Base.establish_connection(db_config)
    Arel::Table.engine = Arel::Sql::Engine.new(ActiveRecord::Base)
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
    res = nil
    OML::Arel::XML::Server::Repository.parse(s2).query.take(1).each do |r|
      res = r.tuple
    end
    assert_equal [2, 1.762236, 0.0], res
  end
  
end
