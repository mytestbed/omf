
require 'omf-web/tab/common/abstract_service'

module OMF::Web::Tab::TwoColumn
  
  class TwoColumn < OMF::Web::Tab::AbstractService
    
    def initialize(tab_id, opts)
      super
      debug "New TwoColumn Service: #{opts.keys.inspect}"      
      @left = opts[:left] || []
      @right = opts[:right] || []      
    end 
    
    def show(req, opts)
      unless @lwidgets
        @lwidgets = @left.collect do |wd| wd[:widget_class].new(wd) end
        @rwidgets = @right.collect do |wd| wd[:widget_class].new(wd) end
      end
      
      OMF::Web::Theme.require 'two_column_page'
      page = OMF::Web::Theme::TwoColumnPage.new(@lwidgets, @rwidgets, opts)
      [page.to_html, 'text/html']
    end

  end # TwoColumn
  
  
end # OMF::Web::Tab::TwoColumn