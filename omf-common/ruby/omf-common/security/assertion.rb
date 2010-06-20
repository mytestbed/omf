
autoload :UUID, 'uuid'

module OMF
  module Security

    class Assertion
      attr_reader :id
      attr_reader :subject
      attr_reader :conditions
      attr_reader :attributes
      
      def add_condition(condition)
        (@condition ||= []) << condition
      end

      def []=(name, value)
        @attributes[name] = value
      end

      def [](name)
        @attributes[name]
      end

      def initialize(subject, attributes = {}, id = UUID.generate())
        @subject = subject
        @id = id
        @attributes = attributes
      end
    end

  end # Security
end # OMF

if $0 == __FILE__

  puts 'HI'
end

