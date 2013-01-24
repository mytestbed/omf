require 'simplecov'
SimpleCov.start { add_filter "/test" }

gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'

require 'omf_common'

#OmfCommon::Comm.init(type: :xmpp)

#OmfCommon.init(:development, {
#  debug: true,
#  communication: { type: :xmpp, server: 'localhost' },
#  eventloop: { type: :em }
#})

OmfCommon::Message.init(type: :xml)

# Shut up all the loggers
Logging.logger.root.clear_appenders
