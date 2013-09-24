# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'sequel'
require 'json'

module OmfEc::Graph
  # Describes a graph which can be displayed through the web interface or any other defined graph visualiser.
  class GraphDescription
    @@gds = {}

    def self.create(name = nil)
      if name
        @@gds[name.to_sym] ||= self.new(name)
      else
        self.new("Unknown #{self.object_id}")
      end
    end

    # Define text to be shown above the graph
    #
    # @param text
    #
    def postfix(text)
      @postfix = text
    end

    # Define the measurement stream to be visualized in
    # the graph. The optional 'context' parameter defines
    # the context in which the MS is used in the graph. This
    # is necessary for graphs, such as 'networks' which need
    # more than one MS to describe the visualization.
    #
    # @param ms_name
    # @param context
    #
    def ms(ms_name, context = :default)
      if (table_name = OmfEc.experiment.mp_table_names[ms_name])
        (@ms[context] ||= []) << (msb = MSBuilder.new(@db[table_name.to_sym]))
      else
        warn "Measurement point '#{ms_name}' NOT defined"
      end
      msb
    end

    # Defines the mapping of columns in the measurement tuples to properties
    # of the visualization.
    #
    # @param mhash Hash of mappings specific to the graph ifentified by 'type'
    def mapping(mhash)
      @mapping = mhash
    end

    def type(gtype)
      @gtype = gtype
    end

    def xaxis(props)
      (@axis ||= {})[:x] = props
    end

    def yaxis(props)
      (@axis ||= {})[:y] = props
    end

    def caption(text)
      @caption = text
    end

    def _report
      info "REPORT:START: #{@name}"
      info "REPORT:TYPE: #{@gtype}"
      info "REPORT:POSTFIX: #{URI.encode(@postfix)}" if @postfix
      @ms.each do |ctxt, a|
        a.each do |ms|
          info "REPORT:MS:#{ctxt}: #{URI.encode(ms.sql)}"
        end
      end
      info "REPORT:MAPPING: #{URI.encode(@mapping.to_json)}"
      if @axis
        info "REPORT:AXIS: #{URI.encode(@axis.to_json)}"
      end
      info "REPORT:CAPTION: #{URI.encode(@caption)}" if @caption
      info "REPORT:STOP"
    end

    protected

    def initialize(name)
      @name = name
      @ms = {}
      # Create a generic Sequel object which can be used to serialize the query.
      # TODO: Make sure this is generic enough
      @db = Sequel.postgres
      @db.instance_variable_set('@server_version', 90105)
    end
  end

  class MSBuilder
    def initialize(data_set)
      @data_set = data_set
    end

    def method_missing(symbol, *args, &block)
      debug "Calling #{symbol}::#{args.inspect}"
      res = @data_set.send(symbol, *args, &block)
      if res.is_a? Sequel::Postgres::Dataset
        @data_set = res
        res = self
      end
      debug "Result: #{res.class}"
      res
    end
  end
end
