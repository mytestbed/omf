module OmfEc
  module Backward
    module AppDefinition
      # The following are OEDL 5 methods

      # Add a new parameter to this Application Definition.
      # This method is for backward compatibility with previous OEDL 5.
      #
      # @param [String] name name of the property to define (mandatory)
      # @param [String] description description of this property
      # @param [String] parameter command-line parameter to introduce this property, including dashes if needed (can be nil)
      # @param [Hash] options list of options associated with this property
      # @option options [String] :type type of the property: :integer, :string and :boolean are supported
      # @option options [Boolean] :dynamic true if the property can be changed at run-time
      # @option options [Fixnum] :order used to order properties when creating the command line
      #
      def defProperty(name = :mandatory, description = nil, parameter = nil, options = {})
        opts = {:description => description, :cmd => parameter}
        # Map old OMF5 types to OMF6
        options[:type] = 'Numeric' if options[:type] == :integer
        options[:type] = 'String' if options[:type] == :string
        options[:type] = 'Boolean' if options[:type] == :boolean
        opts = opts.merge(options)
        define_parameter(Hash[name,opts])
      end

      def defMetric(name,type)
        @fields << {:field => name, :type => type}
      end

      # XXX: This should be provided by the omf-oml glue.
      def defMeasurement(name,&block)
        mp = {:mp => name, :fields => []}
        @fields = []
        # call the block with ourserlves to process its 'defMetric' statements
        block.call(self) if block 
        @fields.each { |f| mp[:fields] << f }
        define_measurement_point(mp)
      end

    end
  end
end
