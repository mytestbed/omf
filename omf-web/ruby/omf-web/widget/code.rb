
module OMF::Web; module Widget; module Code
end; end; end

require 'omf-web/widget/code/code_description'

module OMF::Web::Widget::Code
  
  @@scripts = []
  @@sessions = {}
  
  def self.configure(options = {})
    opts = options.dup
    opts[:scripts] = @@scripts
  
    currDir = File.dirname(__FILE__)
    opts[:resourcePath].insert(0, currDir)
  end
  
  # Register a script which can be visualized through a +CodeWidget+
  #
  # name - Name of script
  # opts -
  #   :???
  # 
  def self.addCode(name, opts = {})
    @@scripts << CodeDescription.new(name, opts)
  end
  
  def self.[](id)
    @@scripts[id]
  end        
  
  def self.count
    @@scripts.length
  end        
  
  def self.each_with_index
    @@scripts.each_index do |i|
      yield @@scripts[i], i
    end
  end
end # OMF::Web::Widget::Code
