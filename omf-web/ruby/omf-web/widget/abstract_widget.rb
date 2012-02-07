
require 'erector'

module OMF::Web::Widget
  
  # Maintains the context for a particular code rendering within a specific session.
  #
  class AbstractWidget < Erector::Widget
    
    attr_reader :widget_id, :name, :opts
    
    def initialize(opts = {})
      @opts = opts
      @widget_id = "w#{object_id}"
      @name = opts[:name] || 'Unknown: Set opts[:name]'
      OMF::Web::SessionStore[@widget_id] = self
    end
        
  end # class
end # OMF::Web::Widget