
module OMF::Web::Tab
  
  @@available_tabs = {}
  @@selected_tabs = {}
  
  def self.register_tab(tab_info)
    id = tab_info[:id] = tab_info[:id].to_sym
    @@available_tabs[id] = tab_info
    MObject.debug(:web, "Registered tab '#{id}'")
  end
  
  def self.description_for(name)
    @@available_tabs[name]
  end
  
  def self.use_tab(tab_id)
    tab_id = tab_id.to_sym
    unless tab = @@available_tabs[tab_id]
      raise "Unknown tab '#{tab_id}'. Need to registered first"
    end
    MObject.debug 'web:tab', "Use tab '#{tab_id}'"
    @@selected_tabs[tab_id] = tab
  end
  
  def self.create_tab(name)
    unless td = @@available_tabs[name.to_sym]
      raise "Can't create unknown tab '#{name}'"
    end
    unless tklass = td[:class]
      # Seems to be a derived tab, look for 'type' and find that
      unless type = td[:type]
        raise "Can't find 'type' definition for tab '#{name}"
      end
      unless pt = @@available_tabs[type.to_sym]
        raise "Unknown tab type '#{type}':()#{@@available_tabs.keys.inspect}"
      end
      unless tklass = pt[:class]
        raise "Don't know which class to use for tab '#{name}/#{type}'"
      end
    end
    tklass.new(name, td[:topts] || {})
  end
  
  def self.selected_tabs(select_also = [])
    select_also.each {|tab_id| use_tab(tab_id) }
    if @@selected_tabs.empty?
      selected = default_tabs()
    else
      selected = @@selected_tabs.values
    end

    selected.sort do |a, b| 
      (a[:priority] || 1000) <=> (b[:priority] || 1000)
    end
  end
  
  # Return an array of tabs wiht their ':def_enabled' set to true. 
  # The array is ordered in 
  # declared tab priority
  #
  def self.default_tabs()
    @@available_tabs.values.select do |t| 
      t[:def_enabled]
    end.sort do |a, b| 
      (a[:priority] || 1000) <=> (b[:priority] || 1000) 
    end
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