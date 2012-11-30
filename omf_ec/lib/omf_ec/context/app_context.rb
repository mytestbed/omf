module OmfEc::Context
  class AppContext
    attr_accessor :name, :app_def, :param_values

    # Keep track of contexts for each app, i.e. multiple contexts can share
    # the same app def. This happens for example when a group can have the 
    # same applications added to it many times, but with different parameter 
    # values for each. Thus we need to distinguish these different context
    @@context_count = Hash.new

    def initialize(name)
      if OmfEc.exp.app_definitions.key?(name)
        self.app_def = OmfEc.exp.app_definitions[name]
        self.param_values = Hash.new
        @@context_count[name] = 0 unless @@context_count.key?(name)
        id = @@context_count[name]
        @@context_count[name] += 1
        self.name = "#{name}_cxt_#{id}"
        self
      else
        raise RuntimeError, "Cannot create context for unknwon application '#{name}'"
      end
    end

    def setProperty(key, value)
      @param_values[key] = value
      self
    end

    def measure
    end

    def properties
      original = app_def.properties.dup   
      p = original.merge({:type => 'application'})
      @param_values.each { |k,v| p[:parameters][k][:value] = v if p[:parameters].key?(k) }
      p
    end    
  end
end
