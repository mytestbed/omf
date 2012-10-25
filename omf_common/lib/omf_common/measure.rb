require 'oml4r'
module OmfCommon
  class Measure
    @@enabled = false
    def Measure.enabled? ; @@enabled end
    def Measure.enable ; @@enabled = true end
  end
end
