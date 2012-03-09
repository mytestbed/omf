class String
  def ducktype
    Integer(self) rescue Float(self) rescue self
  end

  def camelcase
    self.split('_').map(&:capitalize).join('')
  end

  def constant
    self.split('::').inject(Object) { |obj, name| obj = obj.const_get(name); obj }
  end
end
