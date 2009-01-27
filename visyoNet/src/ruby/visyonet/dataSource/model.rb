
module VisyoNet
  class Model < ::MObject
    attr_reader :id
    
    def initialize(id)
      @id = id
      @attr = Hash.new
    end

    def [](name)
      @attr[name]
    end
    
    def []=(name, value)
      #info "Model: #{name}=>#{value}"
      raise "Attribute 'nil'" if name == nil
      @attr[name.to_sym] = value
    end
  end
end
