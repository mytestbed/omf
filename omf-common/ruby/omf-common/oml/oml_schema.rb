

module OMF::Common::OML
  
  # This class represents the schema of an OML measurement stream.
  #
  class OmlSchema < MObject
    
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
    
    def initialize(schema_description)
      @schema = schema_description
      @on_new_vector_proc = {}
    end
  end # OmlSchema
  
end
