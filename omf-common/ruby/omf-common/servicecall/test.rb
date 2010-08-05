require 'omf-common/servicecall'

def run
  uri = "http://localhost:5053"
  OMF::ServiceCall.add_domain(:type => :http,
                              :uri => uri)

  cmc = OMF::Services.cmc
  cmc.inspect

  p cmc.allStatus("norbit").to_s
end

run if __FILE__ == $PROGRAM_NAME
