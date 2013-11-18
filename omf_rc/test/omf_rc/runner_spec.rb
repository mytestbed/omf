# Copyright (c) 2013 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_rc/runner'

describe OmfRc::Runner do
  describe 'when loading a configuration yaml file' do
    before do
      @r = OmfRc::Runner.new
    end

    it 'must initialise options properly' do
      @r.gopts[:config_file] = "#{FIXTURE_DIR}/omf_rc.yml"
      @r.parse_config_files

      @r.opts[:add_default_factories].must_equal true

      @r.opts[:factories][0][:require].must_equal 'omf_rc_openflow'

      @r.opts[:resources][0][:membership].must_equal ['g1']

      @r.opts[:credentials][:root_cert_dir].must_equal '~/omf_keys/root/'
      @r.opts[:credentials][:entity_cert].must_equal '~/omf_keys/rc.pem'
      @r.opts[:credentials][:entity_key].must_equal '~/omf_keys/rc_key.pem'

      @r.opts[:communication][:url].must_equal "xmpp://localhost"
      @r.opts[:communication][:auth][:pdp][:trust].must_equal ['adam']

      @r.opts[:instrumentation]['oml-domain'].must_equal 'domain'
    end

    it 'must support a very minimal configure file with proper defaults' do
      @r.gopts[:config_file] = "#{FIXTURE_DIR}/omf_rc.simple.yml"
      @r.parse_config_files

      @r.opts[:add_default_factories].must_equal true
      @r.opts[:resources][0][:type].must_equal :node

      node_id = Socket.gethostname
      user = "#{node_id}-#{Process.pid}"

      @r.opts[:resources][0][:uid].must_equal node_id
      @r.opts[:communication][:url].must_equal "xmpp://#{user}:#{user}@somewhere"
    end
  end
end
