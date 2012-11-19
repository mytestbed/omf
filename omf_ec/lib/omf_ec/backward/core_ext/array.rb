class Array
  def startApplications
    if !self.empty? && self.all? { |v| v.class == OmfEc::Group }
      self.each { |g| g.startApplications }
    end
  end

  def stopApplications
    if !self.empty? && self.all? { |v| v.class == OmfEc::Group }
      self.each { |g| g.startApplications }
    end
  end
end
