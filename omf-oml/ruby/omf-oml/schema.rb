
require 'omf-common/mobject'
require 'omf-oml'

module OMF::OML
  
  # This class represents the schema of an OML measurement stream.
  #
  class OmlSchema < MObject
    
    CLASS2TYPE = {
      TrueClass => 'boolean',
      FalseClass => 'boolean',
      String => 'string',
      Symbol => 'string',            
      Fixnum => 'decimal',
      Float => 'double',
      Time => 'dateTime'
    }

    
    # Return the col name at a specific index
    #
    def name_at(index)
      @schema[index][:name]
    end
    
    # Return the column names as an array
    #
    def names
      @schema.collect do |col| col[:name] end
    end

    # Return the col type at a specific index
    #
    def type_at(index)
      @schema[index][:type]
    end
    
    def each_column(&block)
      @schema.each do |c| 
       block.call(c) 
      end
    end
    
    def describe
      # @schema.collect do |name, type|
        # if type.kind_of? Class
          # type = CLASS2TYPE[type] || 'unknown'
        # end
        # {:name => name, :type => type}
      # end
      @schema
    end
    
    # schema_description - Array containing [name, type*] for every column in table
    #   TODO: define format of TYPE
    #
    def initialize(schema_description)
      debug "schema: '#{schema_description.inspect}'"
      @schema = schema_description
      #@on_new_vector_proc = {}
    end
  end # OmlSchema
  
end
