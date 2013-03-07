#!/usr/bin/env ruby

require 'rubygems'
require 'blather/client/dsl'
require 'eventmachine'
require 'logger'
require 'securerandom'
require 'monitor'

logger = Logger.new(STDOUT)

#Blather.logger = logger

#logger.level = :debug

class OpenfireTest
  include Blather::DSL
  include MonitorMixin

  attr_accessor :topic_name, :retry_counter, :normal

  def initialize
    @topic_name = "topic_#{rand(100)}"
    @retry_counter = 0
    @normal = false
  end

  def connect
    @client.connect
  end

  def normal_close
    @normal = true

    #EM.after(1) do
    shutdown
    #end
  end
end

@ot = OpenfireTest.new

userid = SecureRandom.uuid

unless ARGV[0]
  puts "Missing argument: The domain name of your XMPP(Openfire) server"
  puts "usage: openfire_test.rb <xmpp server domain name>"
  exit 2
end

@ot.setup("#{userid}@#{ARGV[0]}", "pw")

@ot.disconnected do
  unless @ot.normal
    unless @ot.retry_counter > 0
      @ot.retry_counter += 1
      @ot.connect
    else
      logger.error "In-band registration is OFF. Turn it ON!"
      EM.stop
    end
  else
    logger.info "Exit now"
    @ot.shutdown
  end
end

@ot.when_ready do
  logger.info "Connected as #{@ot.jid}"

  if @ot.jid.node != userid
    logger.error "Annoymous login is ON. Turn it OFF!"
    @ot.normal_close
  else
    logger.info "Annoymous login is OFF. Well done."
    logger.info "In-band registration is ON. Well done."
  end

  pubsub_host = "pubsub.#{@ot.jid.domain}"

  @ot.pubsub.create(@ot.topic_name, pubsub_host) do |stanza|
    if stanza.error?
      logger.error stanza
    else
      logger.info "Can create topic #{@ot.topic_name}"
    end

    @ot.pubsub.subscribe(@ot.topic_name, nil, pubsub_host) do |stanza|
      if stanza.error?
        logger.error stanza
      else
        logger.info "Can subscribe to topic #{@ot.topic_name}"
      end
    end

    @ot.pubsub.subscribe(@ot.topic_name, nil, pubsub_host) do |stanza|
      if stanza.error?
        logger.error stanza
      else
        logger.info "Can subscribe to topic #{@ot.topic_name} again"
      end
    end

    EM.add_timer(4) do
      @ot.pubsub.subscriptions(pubsub_host) do |stanza|
        sub_count = stanza[:subscribed].find_all { |v| v[:node] == @ot.topic_name }

        if sub_count.size > 1
          logger.error "Mutiple subscriptions is ON. Turn it OFF!"
        else
          logger.info "Mutiple subscriptions is OFF. Well done."
        end
      end
    end
  end

  EM.add_timer(5) do
    @ot.pubsub.delete(@ot.topic_name, pubsub_host) do |stanza|
      if stanza.error?
        logger.error stanza
      else
        logger.info "Can delete topic #{@ot.topic_name}"
      end
    end

    EM.add_timer(2) do
      @ot.normal_close
    end
  end
end

EM.run do
  #begin
  @ot.run
  #rescue => e
  #  logger.error e.message
  #end

  trap(:INT) { @ot.normal_close }
  trap(:TERM) { @ot.normal_close }
end
