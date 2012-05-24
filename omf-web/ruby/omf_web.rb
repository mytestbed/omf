
#require 'omf-common/mobject'

module OMF
  module Web
    module Tab; end
    module Rack; end
    module Widget; end
    
    def self.start(opts)
      require 'omf-web/runner'
      require 'thin'
      
      Thin::Logging.debug = true
      OMF::Web::Runner.new(ARGV, opts).run!      
    end
    
    @@datasources = {}
    @@widgets = {}
    def self.register_datasource(data_source, opts = {})
      require 'omf-web/data_source_proxy'
      OMF::Web::DataSourceProxy.register_datasource(data_source, opts)
      
    end
    
    def self.register_widget(widget_descr)
      require 'omf-web/widget/abstract_widget'
      wdescr = transform_keys_to_symbols widget_descr
      OMF::Web::Widget::AbstractWidget.register_widget(wdescr)
    end
    
    def self.register_tab(tab_descr)
      require 'omf-web/tab' 
      tdescr = transform_keys_to_symbols tab_descr
      OMF::Web::Tab.register_tab tdescr    
    end
    
    def self.use_tab(tab_id)
      OMF::Web::Tab.use_tab tab_id          
    end
    
    private
    
    # Adopted from http://www.any-where.de/blog/ruby-hash-convert-string-keys-to-symbols/
    def self.transform_keys_to_symbols(value)
      return value unless value.is_a?(Hash)
      value.inject({}) do |h, (k,v)| 
        h[k.to_sym] = self.transform_keys_to_symbols(v)
        h
      end
    end
    
  end
end


