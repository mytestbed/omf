module OmfEc::Context
  class AppContext
    attr_accessor :def, :param_values

    def initialize(name)
      if OmfEc.exp.app_definitions.key?(name)
        self.def = OmfEc.exp.app_definitions[name]
        self.param_values = Hash.new
        self
      else
        raise RuntimeError, "Cannot create context for unknwon application '#{name}'"
      end
    end

    def setProperty(key, value)
      self.param_values[key] = value
      self
    end

    def measure
    end
  end
end
