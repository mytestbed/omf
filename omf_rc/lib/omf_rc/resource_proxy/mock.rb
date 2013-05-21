# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfRc::ResourceProxy::Mock
  include OmfRc::ResourceProxyDSL

  register_proxy :mock

  utility :mock

  hook :before_ready do |resource|
    logger.info "#{resource.uid} is now ready"
  end

  hook :before_release do |resource|
    logger.info "#{resource.uid} is to be released"
  end
end

