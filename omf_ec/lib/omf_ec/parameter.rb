# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA

module OmfEc
  # This class describes a Parameter
  class Parameter

    attr_reader :id, :name, :description, :defaultValue

    #
    # Create a new Parameter instance
    #
    # - id = parameter identifier
    # - name = name for this parameter
    # - description = short description of this parameter
    # - defaultValue = optional, a defautl value for this parameter (default=nil)
    #
    def initialize(id, name, description, defaultValue = nil)
      @id = id
      @name = name != nil ? name : id
      @description = description
      @defaultValue = defaultValue
    end

    #
    # Return the definition of this Parameter as an XML element
    #
    # [Return] an XML element with the definition of this Parameter
    #
    def to_xml
      a = REXML::Element.new("parameter")
      a.add_attribute("id", id)
      a.add_attribute("name", name)
      if (description != nil)
        a.add_element("description").text = description
      end
      if (defaultValue != nil)
        a.add_element("default").text = defaultValue
      end
      return a
    end

  end
end
