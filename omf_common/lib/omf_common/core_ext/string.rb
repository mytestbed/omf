class String
  def ducktype
    Integer(self) rescue Float(self) rescue self
  end
end
