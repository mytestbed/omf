

module OMF::Communication


  # ????
  class Topic
    # Creates a new topic whose name is scoped in this topic. If +block+
    #is provided, also subscribe to this topic
    #
    def create(topic_name, &onMessage) # string, block => Topic
    end

    # Returns a topic instance if it already exists in PubSub service,
    #  otherwise throw exception. If +block+
    #  is provided, also subscribe to this topic
    def get(topic_name, &onMessage) # string, block => Topic;
    end

    # Subscribe to +topic+ and process any incoming message with +block+.
    #
    def subscribe(&onMessage) # block
    end

    # Unsubscribe from this +topic+
    #
    def unsubscribe()
    end

    # Release this topic
    #
    def release()
    end

    # Call +block+ for any error occuring in the execution of any of the above commands
    #
    def on_error(onError) # block
    end

  end # Topic

end