require 'net/http'
require 'timeout'

module OMF
  module ServiceCall
    module HTTP
      # [domain] :: Uri
      def HTTP.new_http_domain(domainspec)
        lambda do |service, *args|
          service = service || ""
          http_call(domainspec[:uri] + service, *args)
        end
      end

      # [uri] :: Uri
      # [*args] :: [name,value]*
      def HTTP.http_call(uri, *args)
        url = uri.to_s
        query = args.collect do |name, value|
          "#{name}=#{value}"
        end
        url = [url, query.join('&')].delete_if{ |s| s == "" }.join('?')
        begin
          resp = Net::HTTP.get_response(URI.parse(url))
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
      end
    end # module ServiceCall
  end # module HTTP
end # module OMF
