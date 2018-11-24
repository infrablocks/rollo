require 'aws-sdk'
require 'wait'
require 'hollerback'

module Rollo
  module Model
    class Service
      def initialize(
          ecs_cluster_name, ecs_service_arn, region,
              ecs_resource = nil, waiter = nil)
        @ecs_cluster_name = ecs_cluster_name
        @ecs_service_arn = ecs_service_arn
        @ecs_resource = ecs_resource || Aws::ECS::Resource.new(region: region)
        reload

        @waiter = waiter || Wait.new(attempts: 300, timeout: 30, delay: 5)
      end

      def name # ✔︎
        @ecs_service.service_name
      end

      def instance # ✔︎
        @ecs_service
      end

      def reload # ✔︎
        @ecs_service = get_ecs_service
      end

      def is_replica? # ✔︎
        @ecs_service.scheduling_strategy == 'REPLICA'
      end

      def running_count # ✔︎
        @ecs_service.running_count
      end

      def desired_count # ✔︎
        @ecs_service.desired_count
      end

      def desired_count=(count) # ✔︎
        @ecs_resource.client
            .update_service(
                cluster: @ecs_cluster_name,
                service: @ecs_service_arn,
                desired_count: count)
      end

      def has_desired_count? # ✔︎
        running_count == desired_count
      end

      def increase_instance_count_by(count_delta, &block)
        initial = desired_count
        increased = initial + count_delta

        callbacks_for(block).try_respond_with(
            :prepare, initial, increased)

        ensure_instance_count(increased, &block)
      end

      def decrease_instance_count_by(count_delta, &block)
        initial = desired_count
        decreased = initial - count_delta

        callbacks_for(block).try_respond_with(
            :prepare, initial, decreased)

        ensure_instance_count(decreased, &block)
      end

      def ensure_instance_count(count, &block) # ✔︎
        self.desired_count = count
        wait_for_service_health(&block)
      end

      def wait_for_service_health(&block)
        @waiter.until do |attempt|
          reload
          callbacks_for(block)
              .try_respond_with(:waiting_for_health, attempt) if block
          has_desired_count?
        end
      end

      private

      def get_ecs_service
        @ecs_resource.client
            .describe_services(
                cluster: @ecs_cluster_name,
                services: [@ecs_service_arn])
            .services[0]
      end

      def callbacks_for(block)
        Hollerback::Callbacks.new(block)
      end
    end
  end
end
