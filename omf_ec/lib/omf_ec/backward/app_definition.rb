module OmfEc
  module Backward
    module AppDefinition
      # The following are ODEL 5 methods

      # Add a new parameter to this Application Definition
      # This method is for backward compatibility with previous OEDL 5
      #
      # @param [String] name name of the application to define
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
