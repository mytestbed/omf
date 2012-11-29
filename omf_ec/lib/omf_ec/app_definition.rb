require 'securerandom'

module OmfEc
  # Application Definition used in experiment script
  #
  # @!attribute name [String] name of the resource
  class AppDefinition

    # TODO: eventually this calls would mirror all the properties of the App Proxy
    # right now we just have name, binary_path, parameters
    attr_accessor :name, :properties 
    #:binary_path, :parameters

    # @param [String] name name of the application to define
    def initialize(name)
      self.name = name
      self.properties = Hash.new
    end

    # Add new parameter(s) to this Application Definition
    # 
    # @param [Hash] params a hash with the parameters to add
    #
    def define_parameter(params)
      @properties[:parameters] = Hash.new unless @properties.key?(:parameters) 
      if params.kind_of? Hash
        @properties[:parameters].merge!(params)
      else
        error "Cannot define parameter for app '#{self.name}'! Parameter "+
          "not passed as a Hash ('#{params.inspect}')"
      end 
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
