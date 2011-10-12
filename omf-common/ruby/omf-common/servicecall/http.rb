#
# Copyright 2010-2011 National ICT Australia (NICTA), Australia
#
# Copyright 2010-2011 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#

require 'net/http'
require 'timeout'
require 'omf-common/servicecall/endpoint'

module OMF
  module Services
    class HttpEndpoint < Endpoint
      register(:http)

      attr_reader :url
      def initialize(opts)
        super()
        @url = opts[:url]
      end
      
      def make_request(service, method, targets, domain, opts)
        puts ">>>> MAKE REQUEST: service: #{service}, mathod:#{method}, targets: #{targets.inspect}, domain: #{domain}, opts: #{opts.inspect}"
        #send_request()
      end      

      def match?(type, uri, *args)
        return false if not (type == @type and uri == @domain)
        service = args[0]
        method = args[1]
        has_method?(service, method)
      end

      def send_request(service=nil, method=nil, *args)
        uri = url
        if not service.nil?
          uri = uri + "/" + service.to_s
          if not method.nil?
            uri = uri + "/" + method.to_s
          end
        end
        query = args.collect do |name, value|
          "#{name}=#{value}"
        end
        uri = [uri, query.join('&')].delete_if{ |s| s == "" }.join('?')
        puts "URI = #{uri}"
        begin
          resp = Net::HTTP.get_response(URI.parse(uri))
        rescue TimeoutError, Errno::ETIMEDOUT => e
          raise ServiceCall::Timeout, e.message
        rescue \
          Net::HTTPBadResponse,
          Net::HTTPHeaderSyntaxError,
          Net::HTTPClientError,
          Net::HTTPServerError,
          Net::ProtocolError => e
          raise ServiceCall::ProtocolError, e.message
        rescue Errno::ECONNREFUSED, Errno::EINVAL => e
          raise ServiceCall::NoService, e.message
        rescue Exception => e
          raise ServiceCall::Error, e.message
        end
        case resp
        when Net::HTTPSuccess then REXML::Document.new(resp.body)
        else
          resp.error!
        end
      end # send_request
    end # class HttpEndpoint
  end
end # module OMF
