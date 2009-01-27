
require 'visyonet/dataSource/model'

module VisyoNet
  class LinkModel < Model
    attr_reader :fromNode, :toNode
    
    def initialize(id, srcNode, destNode)
      super(id)
      @fromNode = srcNode
      @toNode = destNode
    end
    
    def to_s()
      s = ""
      @attr.each {|k, v| s += "#{k}:#{v} "}
      "#Link:#{@fromNode.id}>#{toNode.id} #{s}>"
    end
    
  end
end
