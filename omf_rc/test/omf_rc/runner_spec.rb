# Copyright (c) 2013 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_rc/runner'

describe OmfRc::Runner do
  describe 'when loading a configuration yaml file' do
    it 'must initialise options properly' do
      runner = OmfRc::Runner.new

      runner.gopts[:config_file] = "#{FIXTURE_DIR}/omf_rc.yml"
      runner.parse_config_files

      runner.opts[:add_default_factories].must_equal true

      runner.opts[:factories][0][:require].must_equal 'omf_rc_openflow'

      runner.opts[:resources][0][:membership].must_equal ['g1']

      runner.opts[:credentials][:root_cert_dir].must_equal '~/omf_keys/root/'
      runner.opts[:credentials][:entity_cert].must_equal '~/omf_keys/rc.pem'
      runner.opts[:credentials][:entity_key].must_equal '~/omf_keys/rc_key.pem'

      runner.opts[:communication][:url].must_equal "xmpp://localhost"
      runner.opts[:communication][:auth][:pdp][:trust].must_equal ['adam']

      runner.opts[:instrumentation]['oml-domain'].must_equal 'domain'
    end
  end
end
