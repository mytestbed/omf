require 'sequel'
require 'securerandom'

module OmfRc
  module ResourceProxy
    class Abstract < Sequel::Model(:resource_proxies)
      plugin :validation_helpers
      plugin :serialization, :json, :properties

      many_to_one :parent, :class => self
      one_to_many :children, :key => :parent_id, :class => self

      def before_validation
        self.uid ||= SecureRandom.uuid
      end

      # Custom validation rules, extend this to validation specific properties
      def validate
        super
        validates_presence [:uid, :type]
        validates_unique :uid
      end

      def before_destroy
        children.each do |child|
          child.destroy
        end
        super
      end

      # Creates a new resource in the context of this resource.
      #
      # @param [Hash] opts options to create new resource
      # @option opts [String] :type Type of resource
      # @option opts [Hash] :properties See +configure+ for explanation
      # @return [Object] the newly created resource
      def create(opts)
        new_resource = self.class.new(opts)
        add_child(new_resource) ? new_resource : nil
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

      # Configure this resource.
      #
      # @param [Hash] configuration configuration key value pair
      def configure(configuration, &on_inform) # Hash, Block
        configuration.each_pair do |key, value|
          properties[key] = value
        end
        save
      end
    end
  end
end
