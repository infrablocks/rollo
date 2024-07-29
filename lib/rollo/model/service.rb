# frozen_string_literal: true

require 'aws-sdk'
require 'wait'
require 'hollerback'

module Rollo
  module Model
    class Service
      def initialize(
        ecs_cluster_name, ecs_service_arn, region,
        ecs_resource = nil, waiter = nil
      )
        @ecs_cluster_name = ecs_cluster_name
        @ecs_service_arn = ecs_service_arn
        @ecs_resource = ecs_resource || Aws::ECS::Resource.new(region:)
        reload

        @waiter = waiter || Wait.new(attempts: 720, timeout: 30, delay: 5)
      end

      def name
        @ecs_service.service_name
      end

      def instance
        @ecs_service
      end

      def reload
        @ecs_service = ecs_service
      end

      def replica?
        @ecs_service.scheduling_strategy == 'REPLICA'
      end

      def running_count
        @ecs_service.running_count
      end

      def desired_count
        @ecs_service.desired_count
      end

      def desired_count=(count)
        @ecs_resource.client
                     .update_service(
                       cluster: @ecs_cluster_name,
                       service: @ecs_service_arn,
                       desired_count: count
                     )
      end

      def desired_count_met?
        running_count == desired_count
      end

      def increase_instance_count_by(count_delta, options = {}, &block)
        maximum = options[:maximum_instance_count] || Float::INFINITY
        initial = desired_count
        increased = initial + count_delta
        target = [increased, maximum].min

        callbacks_for(block).try_respond_with(
          :prepare, initial, target
        )

        ensure_instance_count(target, &block)
      end

      def decrease_instance_count_by(count_delta, options = {}, &block)
        minimum = options[:minimum_instance_count] || 0
        initial = desired_count
        decreased = initial - count_delta
        target = [decreased, minimum].max

        callbacks_for(block).try_respond_with(
          :prepare, initial, target
        )

        ensure_instance_count(target, &block)
      end

      def ensure_instance_count(count, &)
        self.desired_count = count
        wait_for_service_health(&)
      end

      def wait_for_service_health(&block)
        @waiter.until do |attempt|
          reload
          if block
            callbacks_for(block)
              .try_respond_with(:waiting_for_health, attempt)
          end
          desired_count_met?
        end
      end

      private

      def ecs_service
        @ecs_resource.client
                     .describe_services(
                       cluster: @ecs_cluster_name,
                       services: [@ecs_service_arn]
                     )
                     .services[0]
      end

      def callbacks_for(block)
        Hollerback::Callbacks.new(block)
      end
    end
  end
end
