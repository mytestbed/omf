require 'securerandom'

module OmfEc
  # Application Definition used in experiment script
  #
  # @!attribute name [String] name of the resource
  class AppDefinition
    attr_accessor :name, :binary_path, :parameters

    # @param [String] name name of the application to define
    def initialize(name)
      self.name = name
      self.parameters = Hash.new
    end

    # Add new parameter(s) to this Application Definition
    # 
    # @param [Hash] params a hash with the parameters to add
    #
    def define_parameter(params) 
      if params.kind_of? Hash
        self.parameters.merge!(params)
      else
        error "Cannot define parameter for app '#{self.name}'! Parameter "+
          "not passed as a Hash ('#{params.inspect}')"
      end 
    end

    include OmfEc::Backward::AppDefinition
  end
end
