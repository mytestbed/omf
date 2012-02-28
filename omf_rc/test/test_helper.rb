require 'minitest/autorun'
require 'minitest/pride'

require 'json'
require 'sequel'

DB = Sequel.sqlite

DB.create_table :abstracts do
  primary_key :id
  String :type
  String :name
  String :properties, :text => true
  Integer :parent_id
end
