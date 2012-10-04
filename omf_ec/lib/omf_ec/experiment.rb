require 'hashie'

module OmfEc
  class Experiment
    include Singleton

    attr_reader :property

    def initialize
      @property ||= Hashie::Mash.new
    end

    def def_property(name, default_value)
      @property[name] = default_value
    end
  end
end
