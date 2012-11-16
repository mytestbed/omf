module OmfEc
  class AppContext
    attr_accessor :conf

    def initialize(opts)
      self.conf = opts
      self
    end

    def setProperty(key, value)
      self.conf[key] = value
      self
    end

    def measure
    end
  end
end
