# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.


require 'omf_common'
require 'omf_common/lobject'
# require 'yaml'
# require 'log4r'

OMF::Common::Loggable.init_log 'garage_monitor', searchPath: File.dirname(__FILE__)


omf_opts = {
  communication: {
    url: 'amqp://0.0.0.0',
    auth: {}

  },
  eventloop: { type: :em},
  logging: {
    level: 'info'
  }
}

# Configure the web server
#
opts = {
  app_name: 'garage_monitor',
  page_title: 'Garage',
  layout: "#{File.dirname(__FILE__)}/layout.yaml",
  footer_right: 'git:mytestbed/omf',
  static_dirs_pre: ["#{File.dirname(__FILE__)}/htdocs"],
  handlers: {
    # delay connecting to databases to AFTER we may run as daemon
    pre_rackup: lambda do
      load("#{File.dirname(__FILE__)}/garage_monitor.rb")
      GarageMonitor.new(omf_opts)
    end,
    pre_parse: lambda do |p|
      p.separator ""
      p.separator "GARAGE options:"
      p.on '--comms-url URL', "URL to communication layer [#{omf_opts[:communication][:url]}]" do |url|
        omf_opts[:communication][:url] = url
      end
      p.separator ""
    end
  }
}
require 'omf_web'
OMF::Web.start(opts)
