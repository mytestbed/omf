require 'logging'

require "omf_common/version"
require "omf_common/message"
require "omf_common/core_ext/string"

include Logging.globally

Logging.appenders.stdout('stdout',
                         :layout => Logging.layouts.pattern(:date_pattern => '%F %T %z',
                                                            :pattern => '[%d] %-5l %m\n',
                                                            :color_scheme => 'default'))
Logging.logger.root.appenders = 'stdout'
Logging.logger.root.level = :info

module OmfCommon
end
