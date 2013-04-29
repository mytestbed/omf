module OmfEc
  module Backward
    module AppDefinition
      # The following are OEDL 5 methods

      # Add a new parameter to this Application Definition.
      # This method is for backward compatibility with previous OEDL 5.
      #
      # @param [String] name name of the property to define (mandatory)
      # @param [String] description description of this property; oml2-scaffold uses this for the help message (popt: descrip)
      # @param [String] parameter command-line parameter to introduce this property, including dashes if needed (can be nil)
      # @param [Hash] options list of options associated with this property
      # @option options [String] :type type of the property: :integer, :string and :boolean are supported; oml2-scaffold extends this with :int and :double (popt: argInfo)
      # @option options [Boolean] :dynamic true if the property can be changed at run-time
      # @option options [Fixnum] :order used to order properties when creating the command line
      #
      # The OML code-generation tool, oml2-scaffold extends the range of
      # options supported in the options hash to support generation of
      # popt(3) command line parsing code. As for the parameters, depending
      # on the number of dashes (two/one) in parameter, it is used as the
      # longName/shortName for popt(3), otherwise the former defaults to
      # name, and the latter defaults to either :mnemonic or nothing.
      #
      # @option options [String] :mnemonic one-letter mnemonic for the option (also returned by poptGetNextOpt as val)
      # @option options [String] :unit unit in which this property is expressed; oml2-scaffold uses this for the help message (popt: argDescrip)
      # @option options [String] :default default value if argument unspecified (optional; defaults to something sane for the :type)
      # @option options [String] :var_name name of the C variable for popt(3) to store the property value into (optional; popt: arg; defaults to name, after sanitisation)
      #
      # @see http://oml.mytestbed.net/doc/oml/latest/oml2-scaffold.1.html
      # @see http://linux.die.net/man/3/popt
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
