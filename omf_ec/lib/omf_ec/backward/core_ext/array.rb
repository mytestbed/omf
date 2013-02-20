class Array
  def startApplications
    if !self.empty? && self.all? { |v| v.class == OmfEc::Group }
      self.each { |g| g.startApplications }
    end
  end

  def stopApplications
    if !self.empty? && self.all? { |v| v.class == OmfEc::Group }
      self.each { |g| g.stopApplications }
    end
  end

  def exec(name)
    if !self.empty? && self.all? { |v| v.class == OmfEc::Group }
      self.each { |g| g.exec(name) }
    end
  end
end
