require 'omf-common/servicecall'

def run
  uri = "http://localhost:5053"
  
  h = Hash.new(:type => :http, :uri => uri)
  
  OMF::Services.init(h)

  cmc = OMF::Services.call(:service => :cmc, :action => :status, :target => "omf.nicta.node1")
  cmc.inspect
  p cmc

end

run if __FILE__ == $PROGRAM_NAME
