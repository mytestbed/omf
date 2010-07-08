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
# = keyLocator.rb
#
# == Description
#
# Implements functions to locate and verify public and private SSL
# keys and serve them to other classes
#

require 'openssl'
require 'omf-common/sshPubKey'
require 'omf-common/mobject'

module OMF
  module Security
    class KeyLocator < MObject
      @private_key_file = ""
      @public_key_dir = ""
      @authorized_keys = {}

      @private_key = nil
      @signer_id = nil

      attr_reader :private_key, :signer_id

      #
      # Create a new keyLocator
      #
      def initialize(private_key_file, public_key_dir)
        @private_key_file = resolve_path(private_key_file)
        @public_key_dir = resolve_path(public_key_dir)
        info "Using private key '#{private_key_file}', using public keys in '#{public_key_dir}'"
        # Read the private key file for signing our messages
        if not File.exists? private_key_file
          raise "KeyLocator can't find private key '#{private_key_file}'"
        else
          # read file and check if key is valid
          @private_key = OpenSSL::PKey::RSA.new(File.read(@private_key_file))
          # get our own signer id from our public key file
          public_key_file = "#{@private_key_file}.pub"
          if not File.exists? public_key_file
            raise "KeyLocator can't find public key corresponding to '#{private_key_file}'"
          else
            @signer_id = File.read(public_key_file).split(' ')[2].lstrip.rstrip
          end
        end

        # look for public keys with which to verify received messages
        @authorized_keys = Hash.new
        if not File.directory? public_key_dir
          raise "KeyLocator can't find peer public keys directory '#{public_key_dir}'"
        else
          # Find all files in the directory and try to make public keys out of them
          dir = Dir.foreach(public_key_dir) do |file|
            if not file == "." and not file == ".."
              pubkeys_from_file("#{public_key_dir}/#{file}").each do |key, signer|
                if not key.nil?
                  @authorized_keys[signer] = key
                end
              end
            end
          end # Dir.foreach
        end
        # Allow us to verify our own messages
        @authorized_keys[@signer_id] = @private_key
      end

      def find_key(signer_id)
        @authorized_keys[signer_id]
      end

      private

      def pubkeys_from_file(file)
        text = File.readlines(file)
        text.collect do |line|
          if line[0..2] == "ssh"
            signer = line.split(' ')[2].lstrip.rstrip
            key = OpenSSL::PKey.from_pubkey_string(line)
            [key,signer]
          else
            nil
          end
        end.compact
      end

      def resolve_path(path)
        if path[0..1] == "~/"
          return "#{ENV['HOME']}/#{path[2..-1]}"
        else
          return path
        end
      end
    end # class OMF::Security::KeyLocator
  end # module OMF::Security
end # module OMF
