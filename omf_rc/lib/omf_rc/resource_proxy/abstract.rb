require 'omf_common'
require 'securerandom'
require 'hashie'
require 'state_machine'

module OmfRc
  module ResourceProxy
    class Abstract
      attr_accessor :uid, :type, :properties
      attr_reader :state, :children

      state_machine :state, :initial => :inactive do
        event :activate do
          transition :inactive => :active
        end

        event :dectivate do
          transition :active => :inactive
        end
      end

      def initialize(opts)
        opts = Hashie::Mash.new(opts)
        %w(uid type properties).each { |v| self.send("#{v}=", opts.send(v)) }
        @properties ||= Hashie::Mash.new
        @uid ||= SecureRandom.uuid
        @children ||= []
        validate
        self.extend("OmfRc::ResourceProxy::#{type.camelcase}".constant) unless type.to_s == 'abstract'
        super()
      end


      # Custom validation rules, extend this to validation specific properties
      def validate
        # Definitely need a type
        raise StandardError if type.nil?
      end

      # Release a child resource
      def release(resource)
        resource.children.each do |child|
          resource.release(child)
        end
        children.delete(resource)
      end

      def add(resource)
        self.children << resource
        resource
      end

      def get_all(conditions)
        children.find_all do |v|
          flag = true
          conditions.each_pair do |key, value|
            flag &&= v.send(key) == value
          end
        end
      end

      # Creates a new resource in the context of this resource.
      #
      # @param [Hash] opts options to create new resource
      # @option opts [String] :type Type of resource
      # @option opts [Hash] :properties See +configure+ for explanation
      # @return [Object] the newly created resource
      def create(opts)
        add(self.class.new(opts))
      end

      # Returns a resource instance if already exists, in the context of this resource, throw exception otherwise.
      #
      # @param [String] resource_uid Resource' global unique identifier
      # @return [Object] resource instance
      def get(resource_uid) # String => Resource
        resource = children.find { |v| v.uid == resource_uid }
        raise Exception, "Resource #{resource_uid} not found" if resource.nil?
        resource
      end

      # Returns a set of child resources based on properties and conditions
      def request(properties, conditions)
        get_all(conditions).map do |resource|
          Hashie::Mash.new.tap do |mash|
            properties.each do |key|
              mash[key] ||= resource.request_property(key)
            end
          end
        end
      end

      # Configure this resource.
      #
      # @param [Hash] properties property configuration key value pair
      def configure(properties)
        Hashie::Mash.new(properties).each_pair do |key, value|
          configure_property(key, value)
        end
      end

      def configure_property(property, value)
        self.properties.send("#{property}=", value)
      end

      def request_property(property)
        properties.send(property)
      end
    end
  end
end
