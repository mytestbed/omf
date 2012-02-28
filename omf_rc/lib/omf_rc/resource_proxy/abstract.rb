require 'sequel'

module OmfRc
  module ResourceProxy
    class Abstract < Sequel::Model
      plugin :validation_helpers
      plugin :serialization, :json, :properties

      many_to_one :parent, :class => self
      one_to_many :children, :key => :parent_id, :class => self

      def validate
        super
        validates_presence [:name, :type]
        validates_unique :name
      end

      def before_destroy
        children.each do |child|
          child.destroy
        end
        super
      end
    end
  end
end
