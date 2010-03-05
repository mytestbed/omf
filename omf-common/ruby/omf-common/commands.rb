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
# = commands.rb
#
# == Description
#
# This file defines the valid commands used by the entities of OMF.
#

module OmfCommands

  EC_COMMANDS = Set.new [:EXECUTE, :KILL, :STDIN, :NOOP,
                         :PM_INSTALL, :APT_INSTALL, :RPM_INSTALL, :RESET,
                         :REBOOT, :MODPROBE, :CONFIGURE, :LOAD_IMAGE,
                         :SAVE_IMAGE, :LOAD_DATA, :SET_MACTABLE, :ALIAS,
                         :RESTART, :ENROLL, :EXIT]

  RC_COMMANDS = Set.new [:ENROLLED, :WRONG_IMAGE, :OK, :HB, :WARN,
                         :APP_EVENT, :DEV_EVENT, :ERROR, :END_EXPERIMENT]

  AM_SERVICES = Set.new [:INVENTORY, :PXE, :FRISBEE, :SAVEIMAGE,
                         :CMC, :RESULT, :SLICEMGR, :LOGIN ]

  AM_RESPONSES= Set.new [:INVENTORY_REPLY, :PXE_REPLY, :FRISBEE_REPLY,
                         :SAVEIMAGE_REPLY, :CMC_REPLY, :CMCSTUB_REPLY,
                         :RESULT_REPLY, :SLICEMGR_REPLY, :LOGIN_REPLY ]
end
