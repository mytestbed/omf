#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'

require 'net/http'
require 'yaml'
require 'ostruct'
require 'optparse'

require "omf-common/communicator/xmpp/omfPubSubTransport"
require 'omf-oml/table'
require 'omf-oml/sql_source'
require 'omf-web/tabbed_server'
require 'omf-web/tab/graph/init'
require 'omf-web/widget/code/code'

RESULT2_PATH = "/result2/query"
RESULT2_NAMESPACE = "http://schema.mytestbed.net/am/result/2/"
CURRENT_DIR = File.dirname(__FILE__)

@options = OpenStruct.new

OptionParser.new do |opts|
  opts.banner = "Usage: web.rb [options] [experiment_id]"
  opts.separator ""
  opts.separator "Options:"

  opts.on("-c", "--config PATH", "Configuration file") do |path|
    @options.config = path
  end
end.parse!

raise "Missing configuration file" if @options.config.nil?
raise "Missing experiment id" if ARGV[0].nil?

@experiment_id = ARGV[0]
@config = YAML::load_file(@options.config)
@results = []
@result2_uri = URI(@config['data']['result2_server'] + RESULT2_PATH)
@tables = @config['data']['tables']
@mappings = @config['data']['mappings']
@tabs = @config['tabs']

# Monkeypatch String
#
class String
  def auto_parse
    Integer(self) rescue Float(self) rescue self
  end
end

# Add graph widgets
#
def add_graph(name, data_source, viz_type, *column_names)
  x, y, group = *(column_names.map {|v| v.to_sym})

  viz_opts = {
    :schema => data_source.schema,
    :mapping => {
      :x_axis => { :property => x },
      :y_axis => { :property => y },
      :group_by => { :property => group },
      :stroke_width => 2
    }
  }

  OMF::Web::Widget::Graph.addGraph("#{name} #{viz_type}", {
                                    :data_sources => { :default => data_source },
                                    :dynamic => true,
                                    :viz_type => viz_type,
                                    :wopts => viz_opts
                                  })
end

# Add source code tab
# Add all ruby files in the current directory
#
def add_code
  Dir.glob("*.rb").each do |filename|
    OMF::Web::Widget::Code.addCode(
      filename,
      :file => "#{CURRENT_DIR}/#{filename}"
    )
  end
end

def result2_data_rows(experiment_id, uri, tables, mappings)
  results = []
  data_rows = []

  req = Net::HTTP::Post.new(uri.path)

  result2_queries = tables.map do |table|
    Nokogiri::XML::Builder.new do |xml|
      xml.request(:id => 'foo') {
        xml.result { xml.format 'xml' }
        xml.query {
          xml.repository(:name => experiment_id)
          xml.table(:tname => table)
          xml.project {
            mappings['columns'].each do |m|
              xml.arg { xml.col(:name => m['name'], :table => table) }
            end
          }
        }
      }
    end.to_xml
  end

  result2_queries.each do |result_query|
    req.body = result_query
    Net::HTTP.start(uri.host, uri.port) do |http|
      res = http.request(req)
      results << res.body
    end
  end

  results.each do |result|
    Nokogiri::XML(result).xpath('//omf:r', 'omf'=> RESULT2_NAMESPACE).each do |r|
      row = r.xpath('omf:c', 'omf'=> RESULT2_NAMESPACE).map {|v| v.content.auto_parse }
      data_rows << row
    end
  end

  data_rows.group_by {|r| r[0]}
end

# Configure data source
#
schema = @mappings['columns'].map {|v| [v['name'].to_sym, v['type'].to_sym]}
@data_source = OMF::OML::OmlTable.new(@experiment_id, schema, :index => @mappings['index'])

grouped_rows = result2_data_rows(@experiment_id, @result2_uri, @tables, @mappings)

grouped_rows.keys.sort.each do |key|
  grouped_rows[key].each do |row|
    @data_source.add_row(row)
  end
end

@tabs['graph']['widgets'].each do |widget|
  add_graph(@tabs['graph']['title'], @data_source, widget, *(@mappings['columns'].map {|v| v['name']}))
end

add_code

OMF::Web.start({
  :page_title => @config['title'],
  :use_tabs => @tabs.keys.map {|v| v.to_sym},
  :theme => 'bright'
})


