

module OMF::Web::Theme
  @@theme = 'traditional'
  
  def self.theme=(theme)
    @@theme = theme if theme
  end
  
  def self.require(name)
    Kernel::require "omf-web/theme/#{@@theme}/#{name}.rb"
  end
end