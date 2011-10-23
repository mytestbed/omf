
module OMF::Web::Tab
  
  @@available_tabs = {}
  
  def self.register_tab(tab_info)
    id = tab_info[:id]
    @@available_tabs[id] = tab_info
    MObject.debug(:web, "Registered tab '#{id}'")
  end
  
  def self.description_for(name)
    @@available_tabs[name]
  end
  
  # Return an array of available tabs. The array is ordered in 
  # declared tab priority
  #
  def self.available_tabs()
    @@available_tabs.values.sort do |a, b| 
      (a[:priority] || 1000) <=> (b[:priority] || 1000) 
    end
  end
  
end