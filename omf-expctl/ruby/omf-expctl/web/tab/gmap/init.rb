require 'omf-expctl/web/tab/gmap/gmapServlet'

include OMF::ExperimentController
Web.registerService Web::GMap, :name => :map, :priority => 400, :def_enabled => false
