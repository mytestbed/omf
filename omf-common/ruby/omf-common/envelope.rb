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

require 'rexml/document'
require 'xmlcanonicalizer'

module OMF
  module Envelope

    @@envelope_generator = nil

    def self.init(opts)
      authenticate = opts[:authenticate_messages] || false
      key_locator = opts[:key_locator]
      if !authenticate then
        @@envelope_generator = EnvelopeGenerator.new
      else
        if key_locator.nil? then
          raise "Message authentication is enabled but no KeyLocator found."
        end
        @@envelope_generator = AuthEnvelopeGenerator.new(key_locator)
      end
    end

    #
    #  Returns the message wrapped in whatever envelope is appropriate
    #  for the current security environment.  If signing is enabled,
    #  this signs the message and returns it wrapped in the signature
    #  envelope.  If signing is not enabled, this method is the identity
    #  method.
    #
    def add_envelope(message)
      #puts "Adding envelope"
      generator.wrap(message)
    end

    #
    #  Removes the envelope from this message, if appropriate, and
    #  returns the body of the message itself.  If signing is enabled,
    #  there will be a signature envelope present and it will be removed
    #  and the message returned.  Otherwise this method is the identity
    #  method.
    #
    #  Note:  this method does not verify the signature if present.
    #
    def remove_envelope(message)
      generator.strip(message)
    end

    #
    #  Verifies the integrity of the message.  If signing is enabled,
    #  this method looks up the appropriate key and verifies the message
    #  based on the information in the message envelope.  If signing is
    #  not enabled, this method always returns true (i.e. all messages
    #  should be accepted).
    #
    #  If the message verification fails then this method returns false.
    #  Otherwise it returns true.
    #
    def verify(message)
      generator.verify(message)
    end

    #
    # The default envelope handler doesn't modify messages (i.e. no
    # envelope is added/stripped) and always decides that a message
    # verified successfully (i.e. no verification).
    #
    class EnvelopeGenerator < MObject

      @envelope = nil
      @message = nil

      def check_message_type(message)
        return if message.class() == REXML::Document || message.class == REXML::Element
        raise "Message is not an XML document - '#{message.to_s}'"
      end

      def wrap(message)
        check_message_type(message)
        message.elements[1].add_attribute("id", "omf-payload")
        envelope = REXML::Document::new
        envelope << REXML::Element.new("omf-message")
        envelope.root << message
        envelope
      end

      def strip(envelope)
        check_message_type(envelope)
        if envelope.equal?(@envelope) then
          @message
        else
          if verify(envelope) then
            @message
          else
            nil
          end
        end
      end

      def verify(envelope)
        check_message_type(envelope)
        @envelope = envelope
        if not envelope.elements["//sig:signature"].nil? then
          warn "Message appears to be signed, but authentication is not enabled #{envelope.to_s}"
        end
        if envelope.name == "omf-message" then
          # Return the first element as the message payload
          @message = envelope.elements[1]
          return true
        else
          raise "Unrecognized message body #{envelope}"
        end
      end
    end

    private

    class AuthEnvelopeGenerator < EnvelopeGenerator

      def wrap(message)
        check_message_type(message)

        message.elements[1].add_attribute("id", "omf-payload")
        envelope = super(message)
        envelope.root.add_namespace("sig", "http://omf.mytestbed.net/xmldsig#")

        el_sig = REXML::Element.new("sig:signature")
        el_sig.add_attribute("over", "omf-payload")
        el_sig.add_attribute("signer", @key_locator.signer_id)

        c = XML::Util::XmlCanonicalizer.new(false,true)
        text = c.canonicalize(message)
        key = @key_locator.private_key
        signature = key.sign(OpenSSL::Digest::SHA1.new, text)
        signature = Base64.encode64(signature)
        el_sig.text = signature

        envelope.root << el_sig
        envelope
      end

      def verify(envelope)
        check_message_type(envelope)
        @envelope = envelope
        if envelope.name == "omf-message" then
          message = envelope.elements[1]
          over = message.attributes["id"]
          envelope.each_element_with_attribute("over", over) do |e|
            signer = e.attributes["signer"]
            pubkey = @key_locator.find_key(signer)
            return false if pubkey.nil?
            c = XML::Util::XmlCanonicalizer.new(false,true)
            text = c.canonicalize(message)
            b64 = e.text.split("\n").join
            signature = Base64.decode64(b64)
            result = pubkey.verify(OpenSSL::Digest::SHA1.new, signature, text)
            if result then
              @message = message
            else
              @message = nil
            end
            return result
          end
        else
          raise "Unrecognized message body #{envelope}"
        end
        false
      end

      def initialize(key_locator)
        @key_locator = key_locator
      end
    end

    def generator
      MessageEnvelope.init(nil) if @@envelope_generator.nil?
      @@envelope_generator
    end
  end # module MessageEnvelope
end # module OMF
