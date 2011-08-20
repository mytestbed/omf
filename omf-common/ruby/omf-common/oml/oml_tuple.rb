
module OMF::Common::OML
  
  require 'omf-common/oml/oml_schema'
  

  # This class represents a single vector from an OML measurement stream.
  # It provides various methods to access the vectors elements.
  #
  # NOTE: Do not store the vector itself, but make a copy as the instance may be 
  # reused over various rows by the sender.
  #
  class OmlTuple < MObject
    
    # Return a specific element of the tuple identified either
    # by it's name, or its col index
    #
    def [](name_or_index)
      @vprocs[name_or_index].call(@raw)
    end
    
    # Return the elements of the vector as an array
    def to_a(include_index_ts = false)
      res = []
      r = @raw
      if include_index_ts
        res << @vprocs[:oml_ts].call(r)
        res << @vprocs[:oml_seq_no].call(r)
      end
      @schema.each do |col|
        res << @vprocs[col[:name]].call(r)
      end
      res
    end
    
    # Return an array including the values for the names elements
    # given as parameters.
    #
    def select(*col_names)
      r = @raw
      col_names.collect do |n|
        p = @vprocs[n]
        p ? p.call(r) : nil
      end
    end
        
    attr_reader :schema

    def ts
      @raw[0].to_f
    end
    
    def seq_no
      @raw[1].to_i
    end
    
    attr_reader :stream_name
    
    def initialize(stream_name, schema)
      super stream_name
      @stream_name = stream_name
      if schema.kind_of? Array
        schema = OmlSchema.new(schema)
      end
      @schema = schema
      @raw = []
#      puts "SCHEMA: #{schema.inspect}"
      process_schema(schema)
    end
    
    def process_schema(schema)
      i = 0
      @vprocs = {}
      schema.each_column do |col| #
        name = col[:name]
        type = col[:type]
        j = i + 2; # need to create a locally scoped variable for the following lambdas
        @vprocs[name] = @vprocs[i] = case type      
          when :string : lambda do |r| r[j] end
          when :double : lambda do |r| r[j].to_f end
          else raise "Unrecognized OML type '#{type}'"
        end
        i += 1
      end
      @vprocs[:oml_ts] = lambda do |r| r[0].to_f end
      @vprocs[:oml_seq_no] = lambda do |r| r[1].to_i end
    end
    
    # Parse the array of strings into the proper typed vector elements
    #
    # NOTE: We assume that each element is only called at most once, with some
    # never called. We therefore delay typecasting to the get function without
    # keeping the casted values (would increase lookup time)
    #
    def parse_tuple(els)
      @raw = els
      #puts "RAW: #{els.length} #{els.join(' ')}"
      
      # ts, index, *rest = els
      # @ts = ts.to_f
      # @seq_no = index.to_i
# 
      # @row.clear
      # rest.each_index do |i|
        # name, unused, typeProc = @schema[i]
        # value = rest[i]
        # @row << typeProc.call(value)
      # end
      
      @on_new_vector_proc.each_value do |proc|
        proc.call(self)
      end
      
    end
  end # OmlTuple
end # OMF::Common::OML
