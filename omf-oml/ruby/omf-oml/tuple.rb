
require 'omf-common/mobject'
require 'omf-oml'
require 'omf-oml/schema'

module OMF::OML
  
  # This class represents a tuple with an associated schema. 
  # It provides various methods to access the tuple elements.
  #
  # NOTE: Do not store the tuple itself, but make a copy as the instance may be 
  # reused over various rows by the sender.
  #
  # Use +OmlTuple+ if the schema is an OML one. +OmlTuple+ has additional convenience
  # methods.
  #
  class Tuple < MObject
    
    # Return a specific element of the tuple identified either
    # by it's name, or its col index
    #
    def [](name_or_index)
      @vprocs[name_or_index].call(@raw)
    end
    
    # Return the elements of the tuple as an array
    def to_a()
      res = []
      r = @raw
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
    attr_reader :stream_name
    
    def initialize(name, schema)
      if schema.kind_of? Array
        schema = OmlSchema.new(schema)
      end
      @stream_name = name
      @schema = schema
      
      @raw = []
#      puts "SCHEMA: #{schema.inspect}"

      super name
      process_schema(schema)
    end
    
    
    # Parse the array of strings into the proper typed vector elements
    #
    # NOTE: We assume that each element is only called at most once, with some
    # never called. We therefore delay type-casting to the get function without
    # keeping the casted values (would increase lookup time)
    #
    def parse_tuple(els)
      @raw = els      
      @on_new_vector_proc.each_value do |proc|
        proc.call(self)
      end
    end
    
    protected
    def process_schema(schema)
      i = 0
      @vprocs = {}
      schema.each_column do |col| #
        name = col[:name] || raise("Ill-formed schema '#{schema}'")
        type = col[:type] || raise("Ill-formed schema '#{schema}'")
        @vprocs[name] = @vprocs[i] = case type      
          when :string : lambda do |r| r[i] end
          when :double : lambda do |r| r[i].to_f end
          else raise "Unrecognized Schema type '#{type}'"
        end
        i += 1
      end
    end
 
  end # Tuple
end # OMF::OML
