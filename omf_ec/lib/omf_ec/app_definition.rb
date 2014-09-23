require 'securerandom'

module OmfEc
  # Application Definition used in experiment script
  #
  # @!attribute name [String] name of the resource
  class AppDefinition

    # TODO: eventually this call would mirror all the properties of the App Proxy
    # right now we just have name, binary_path, parameters
    attr_accessor :name, :properties

    # @param [String] name name of the application to define
    def initialize(name)
      self.name = name
      self.properties = Hashie::Mash.new
    end

    # Add new parameter(s) to this Application Definition
    #
    # @param [Hash] params a hash with the parameters to add
    #
    def define_parameter(params)
      @properties[:parameters] = Hashie::Mash.new unless @properties.key?(:parameters)
      if params.kind_of? Hash
        @properties[:parameters].merge!(params)
      else
        error "Cannot define parameter for app '#{self.name}'! Parameter "+
          "not passed as a Hash ('#{params.inspect}')"
      end
    end

    def define_measurement_point(mp)
      @properties[:oml] = Hashie::Mash.new unless @properties.key?(:oml)
      if mp.kind_of? Hash
        @properties[:oml][:available_mps] = Array.new unless @properties[:oml].key?(:available_mps)
        @properties[:oml][:available_mps] << mp
      else
        error "Cannot define Measurement Point for app '#{self.name}'! MP "+
          "not passed as a Hash ('#{mp.inspect}')"
      end
    end

    def path=(arg)
      @properties[:binary_path] = arg
    end

    def shortDescription=(arg)
      @properties[:description] = arg
      warn_deprecation :shortDescription=, :description=
    end

    def method_missing(method_name, *args)
      k = method_name.to_sym
      return @properties[k] if @properties.key?(k)
      m = method_name.to_s.match(/(.*?)([=]?)$/)
      if m[2] == '='
        @properties[m[1].to_sym] = args.first
      else
        super
      end
    end

    include OmfEc::Backward::AppDefinition
  end
end
