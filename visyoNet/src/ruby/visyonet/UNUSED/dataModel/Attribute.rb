
class Attribute
  attr_reader :name, :value
  
  def initialize(name, value)
    set(name, value)
  end
  
private
  def set(name, value)
    @name = name
    @value = value
  end
  
  # member variables
  @name = nil
  @value = nil
end