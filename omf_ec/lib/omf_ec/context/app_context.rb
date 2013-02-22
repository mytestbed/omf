module OmfEc::Context
  class AppContext
    attr_accessor :name, :app_def, :param_values, :oml_collections

    # Keep track of contexts for each app, i.e. multiple contexts can share
    # the same app def. This happens for example when a group can have the 
    # same applications added to it many times, but with different parameter 
    # values for each. Thus we need to distinguish these different context
    @@context_count = Hash.new

    def initialize(name)
      if OmfEc.experiment.app_definitions.key?(name)
        self.app_def = OmfEc.experiment.app_definitions[name]
        self.param_values = Hash.new
        self.oml_collections = Array.new
        @@context_count[name] = 0 unless @@context_count.key?(name)
        id = @@context_count[name]
        @@context_count[name] += 1
        self.name = "#{name}_cxt_#{id}"
        self
      else
        raise RuntimeError, "Cannot create context for unknwon application '#{name}'"
      end
    end

    def setProperty(key, property_value)
      if property_value.kind_of?(ExperimentProperty)
        @param_values[key] = property_value.value
        # TODO: here we need to register a Proc block to the ExperimentProperty 
        # if this property has its dynamic attribute set to true, so that
        # our Proc block would be called by ExperimentProperty each time the
        # property changes value
        # In this callback we will send a 'configure' to the application
      else
        @param_values[key] = property_value
      end
      self
    end

    # For now this follows v5.4 syntax...
    # We have not yet finalised an OML syntax inside OEDL for v6
    def measure(mp,filters)
      collection = {:url => OmfEc.experiment.oml_uri, :streams => [] }
      stream = { :mp => mp , :filters => [] }.merge(filters)
      collection[:streams] << stream
      @oml_collections << collection
    end

    def properties
      # deep copy the properties from the our app definition
      original = Marshal.load(Marshal.dump(app_def.properties)) 
      p = original.merge({:type => 'application'})
      @param_values.each { |k,v| p[:parameters][k][:value] = v if p[:parameters].key?(k) }
      if @oml_collections.size > 0
        p[:use_oml] = true
        p[:oml][:id] = @name
        p[:oml][:experiment] = OmfEc.experiment.id
        p[:oml][:collection] = @oml_collections      
      end
      p
    end    
  end
end
