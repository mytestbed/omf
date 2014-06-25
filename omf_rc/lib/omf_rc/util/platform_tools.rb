# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

#
# Copyright (c) 2012 National ICT Australia (NICTA), Australia
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# This module defines a Utility with some common work blocks that handle the
# installation of software on a given OS platform
#
module OmfRc::Util::PlatformTools
  include OmfRc::ResourceProxyDSL

  utility :common_tools
  utility :fact

  # This utility block logs attempts to detect the OS platform on which it is
  # currently running. Right now it can recognise the following platform:
  # - Ubuntu (by looking for an Ubuntu string in /etc/*release files)
  # - Fedora (by looking for a Fedora string in /etc/*release files)
  #
  # Further methods and OS platform may be supported later
  #
  # [Symbol] either :unknown | :ubuntu | :fedora
  #
  work('detect_platform') do |res|
    os = res.request_fact_osfamily
    case os
    when 'RedHat' then :fedora
    when 'Debian' then :ubuntu
    else :unknown
    end
  end

  # This utility block logs attempts to validate if a given package name is
  # a valid one or not. Right now it checks the following:
  # - if the given pkg name is not nil
  # - if the given pkg name has a size > 0
  #
  # Further checks may be implemented later
  # (e.g. is the pkg provided by any known repository, etc...)
  #
  # @yieldparam [String] pkg_name the package name to check
  #
  # [Boolean] true or fals
  #
  work('valid_pkg_name') do |res, pkg_name|
    valid_name = false
    plat = res.detect_platform
    logger.debug "Platform: '#{plat}' - Installing: '#{pkg_name}'"
    valid_name = true unless pkg_name.nil? || (pkg_name.to_s.size == 0)
    res.log_inform_error "Package name is not defined for "+
      "platform: '#{plat}'. Abort install!" unless valid_name
    valid_name
  end

  # This utility block install a package on an Ubuntu platform using
  # the underlying apt-get tool
  #
  # @yieldparam [String] pkg_name the package name to install
  #
  work('install_ubuntu') do |res, pkg_name|
    next false unless res.valid_pkg_name(pkg_name)
    ExecApp.new("#{res.hrn.nil? ? res.uid : res.hrn}_INSTALL",
                res,
                "LANGUAGE='C' LANG='C' "+
                "LC_ALL='C' DEBIAN_FRONTEND='noninteractive' "+
                "apt-get install --reinstall --allow-unauthenticated -qq "+
                "#{pkg_name}")
  end

  # This utility block install a package on an Fedora platform using
  # the underlying yum tool
  #
  # @yieldparam [String] pkg_name the package name to install
  #
  work('install_fedora') do |res, pkg_name|
    next false unless res.valid_pkg_name(pkg_name)
    ExecApp.new("#{res.hrn.nil? ? res.uid : res.hrn}_INSTALL",
                res,
                "/usr/bin/yum -y install #{pkg_name}")
  end

  # This utility block install a software from a tarball archive. It first
  # tries to download the tarball at a given URI (if it has not been
  # downloaded earlier), then it unarchives it at the given install_path
  #
  # @yieldparam [String] pkg_name the package name to install
  # @yieldparam [String] install_path the path where to install this package
  #
  work('install_tarball') do |res, pkg_name, install_path|
    next false unless res.valid_pkg_name(pkg_name)
    require 'net/http'
    require 'uri'
    require 'digest/md5'

    file = "/tmp/#{File.basename(pkg_name)}"
    if file.empty?
      res.log_inform_error "Failed to parse URI '#{pkg_name}'. Abort install!"
      next false
    end

    eTagFile = "#{file}.etag"
    download = true
    cmd = ""
    remoteETag = nil

    # get the ETag from the HTTP header
    begin
      uri = URI.parse(pkg_name)
      result = Net::HTTP.start(uri.host, uri.port) do |http|
        header = http.request_head(pkg_name)
        remoteETag = header['etag']
      end
    rescue => err
      res.log_inform_error "Failed to access URL '#{pkg_name}'"+
                           " (error: #{err}). Abort install!"
      next false
    end

    # if we have the file and its ETag locally,
    # compare it to the ETag of the remote file
    if File.exists?(file) && File.exists?(eTagFile)
       f=File.open(eTagFile,'r')
       localETag=f.gets
       f.close
       download = false if remoteETag == localETag
     end

    # download the file & store the ETag if necessary
    if download
      logger.debug "Downloading '#{pkg_name}'"
      # -m -nd overwrites existing files
      cmd="wget -P /tmp -m -nd -q #{pkg_name};"
      unless remoteETag.empty?
        f=File.open(eTagFile,'w')
        f.write remoteETag
        f.close
      end
    else
      logger.debug "Local file '#{file}' already exists and is "+
                   "identical to '#{pkg_name}'"
    end
    # Finally unarchive the file at the requested install path
    cmd += "tar -C #{install_path} -xf #{file}"
    id = "#{res.hrn.nil? ? res.uid : res.hrn}_INSTALL"
    ExecApp.new(id, res, cmd, false)
  end

end
