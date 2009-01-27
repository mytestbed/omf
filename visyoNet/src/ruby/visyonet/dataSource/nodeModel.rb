
require 'visyonet/dataSource/model'

module VisyoNet
  class NodeModel < Model

    def initialize(id)
      super(id)
    end
    
    def to_s()
      s = ""
      @attr.each {|k, v| s += "#{k}:#{v} "}
      "#<Node:#{@id} #{s}>"
    end
  end

end
