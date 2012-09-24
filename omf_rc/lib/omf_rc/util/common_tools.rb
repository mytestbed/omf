# This module defines a Utility with some common work blocks that could be
# useful to any type of Resource Proxy (RP)
module OmfRc::Util::CommonTools
  include OmfRc::ResourceProxyDSL

  # This utility block logs an error/warn String S on the resource proxy side
  # and publish an INFORM message on the resources pubsub topic. This INFORM
  # message will have the type ERROR/WARN, and its 'reason' element set to the
  # String S
  #
  %w(error warn).each do |type|
    work("log_inform_#{type}") do |res, msg|
      logger.send(type, msg)
      res.comm.publish(res.uid,
                       OmfCommon::Message.inform(type.upcase) do |message|
                         message.element('reason' , msg)
                       end)
    end
  end
end
