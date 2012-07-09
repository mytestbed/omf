gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'

require 'omf_rc'
require 'omf_rc/resource_factory'

# Shut up all the loggers
Logging.logger.root.clear_appenders
