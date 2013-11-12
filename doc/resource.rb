
module OMF::Communication

  # ????
  class Resource
    # Creates a new resource in the context of this resource
    #
    #   opts:
    #    - type
    #    - name
    #    - configuration - See +configure+ for explanation
    #
    def create(opts) # Hash => Resource

    # Returns a resource instance if it already exists,
    # otherwise throw exception.
    #
    def get(resource_name) # String => Resource
    end

    # Configure this resource. If +on_inform+ is provided, it will receive INFORM messages
    # which are sent by the actual resource in response to CONFIGURE.
    #
    def configure(configuration, &on_inform) # Hash, Block
    end

    # Request the state of the resource. If +property_names+ is Configure this resource. If +on_inform+ is provided, it will receive INFORM messages
    # which are sent by the actual resource in response to CONFIGURE.
    #
    def request(property_names, conditions, &on_inform) # Array || nil, Hash || nil, Block
    end

    # Register a +block+ to process any INFORM message sent by this resource.
    # The +context+  allows the re-definition of a different block for the
    # same context. Providing no block to a previously set context, cancels the
    # callback.
    #
    def on_inform(context, &on_inform) # Object, Block
    end

    def release()
    end
  end;


end.