module OmfEc
  module Backward
    module DefaultEvents

      class << self
        def included(base)
          base.instance_eval do
            def_event :ALL_UP do |state, plan|
              !plan.keys.empty? && plan.keys.all?  do |k|
                plan[k].sort == state.find_all { |v| v[:membership] && v[:membership].include?(k) }.map { |v| v[:uid] }.sort
              end
            end

            def_event :ALL_UP_AND_INSTALLED do
            end

            def_event :ALL_INTERFACE_UP do
            end
          end
        end
      end

    end
  end
end
