module Rollo
  module Model
    class Host
      def initialize(instance)
        @instance = instance
      end

      def id
        @instance.id
      end

      def terminate
        @instance.terminate(should_decrement_desired_capacity: false)
      end

      def is_in_service?
        @instance.lifecycle_state == 'InService'
      end

      def is_healthy?
        @instance.health_status == 'Healthy'
      end
    end
  end
end
