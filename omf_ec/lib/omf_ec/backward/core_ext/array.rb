# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

class Array
  def startApplications
    if !self.empty? && self.all? { |v| v.class == OmfEc::Group }
      self.each { |g| g.startApplications }
    end
  end

  def startApplication(app_name)
    if !self.empty? && self.all? { |v| v.class == OmfEc::Group }
      self.each { |g| g.startApplication(app_name) }
    end
  end

  def startApplication(app_name)
    if !self.empty? && self.all? { |v| v.class == OmfEc::Group }
      self.each { |g| g.startApplication(app_name) }
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
