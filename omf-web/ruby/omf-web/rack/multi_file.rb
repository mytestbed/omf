
require 'rack/file'

module OMF::Web::Rack
  # Rack::MultiFile serves files which it looks for below an array
  # of +roots+ directories given, according to the
  # path info of the Rack request.
  #
  # Handlers can detect if bodies are a Rack::File, and use mechanisms
  # like sendfile on the +path+.
  #
  class MultiFile < ::Rack::File
    def initialize(roots, cache_control = nil)
      super nil, cache_control
      @roots = roots
    end
    
    def _call(env)
      @path_info = ::Rack::Utils.unescape(env["PATH_INFO"])
      parts = @path_info.split SEPS

      return fail(403, "Forbidden")  if parts.include? ".."

      @roots.each do |root|
        @path = F.join(root, *parts)
        available = begin
          F.file?(@path) && F.readable?(@path)
        rescue SystemCallError
          false
        end

        if available
          return serving(env)
        end
      end
      fail(404, "File not found: #{@path_info}")
    end # _call
    
  end # MultiFile
end # module



