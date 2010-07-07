#
# Copyright (c) 2010 National ICT Australia (NICTA), Australia
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
#
#
# = omfProtocol.rb
#
# == Description
#
# This file defines some constants and attributes on the protocols used by
# the OMF entities to communicate with each other
#

module OmfProtocol

  # Commands issued by the EC
  EC_COMMANDS = Set.new [:EXECUTE, :KILL, :STDIN, :NOOP, 
                        :PM_INSTALL, :APT_INSTALL, :RPM_INSTALL, :RESET, 
                        :REBOOT, :MODPROBE, :CONFIGURE, :LOAD_IMAGE,
                        :SAVE_IMAGE, :LOAD_DATA, :SET_LINK, :ALIAS,
                        :SET_DISCONNECTION, :RESTART, :ENROLL, :EXIT]

  # Commands issued by the RC
  RC_COMMANDS = Set.new [:ENROLLED, :WRONG_IMAGE, :OK, :KILL, :WARN, 
                        :APP_EVENT, :DEV_EVENT, :ERROR, :END_EXPERIMENT]

  # Commands issued by the RM
  RM_COMMANDS = Set.new [:OK, :WARN, :ERROR]

  # Commands issued by the Slice Manager
  SLICEMGR_COMMANDS = Set.new [:CREATE_SLIVER, :DELETE_SLIVER, :EXECUTE, 
                               :KILL, :EXIT]

  # Commands issued by the OTHER
  OTHER_COMMANDS = Set.new [:XYZ]

  def self.ec_cmd?(cmd) 
    return EC_COMMANDS.include?(cmd.to_s.upcase.to_sym) 
  end

  def self.rc_cmd?(cmd) 
    return RC_COMMANDS.include?(cmd.to_s.upcase.to_sym) 
  end

  def self.rm_cmd?(cmd) 
    return RM_COMMANDS.include?(cmd.to_s.upcase.to_sym) 
  end

  def self.slicemgr_cmd?(cmd) 
    return SLICEMGR_COMMANDS.include?(cmd.to_s.upcase.to_sym) 
  end

  def self.other_cmd?(cmd)
    return INVENTORY_COMMANDS.include?(cmd.to_s.upcase.to_sym)
  end    

end

