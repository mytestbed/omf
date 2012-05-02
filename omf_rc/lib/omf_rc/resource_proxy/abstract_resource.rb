require 'omf_common'
require 'securerandom'
require 'hashie'

class OmfRc::ResourceProxy::AbstractResource
  attr_accessor :uid, :type, :properties
  attr_reader :children

  def initialize(type, opts = nil)
    opts = Hashie::Mash.new(opts)
    @type = type
    @uid = opts.uid || SecureRandom.uuid
    @properties = Hashie::Mash.new(opts.properties)
    @children ||= []
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
      flag
    end
  end

  # Creates a new resource in the context of this resource.
  #
  # @param [Hash] opts options to create new resource
  # @option opts [String] :type Type of resource
  # @option opts [Hash] :properties See +configure+ for explanation
  # @return [Object] the newly created resource
  def create(type, opts = nil)
    add(OmfRc::ResourceFactory.new(type, opts))
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
  def request(properties, conditions = {})
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
    properties.send("#{property}=", value)
  end

  def request_property(property)
    properties.send(property)
  end
end
