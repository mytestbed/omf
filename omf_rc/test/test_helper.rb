gem 'minitest'
require 'minitest/autorun'
require 'minitest/pride'

require 'omf_rc'
require 'omf_rc/resource_factory'

OmfRc::ResourceFactory.load_default_resource_proxies

# Shut up all the loggers
Logging.logger.root.clear_appenders
