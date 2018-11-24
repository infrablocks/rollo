require 'aws-sdk'
require 'hollerback'

require_relative './scaling_activity'
require_relative './host'

module Rollo
  module Model
    class HostCluster
      def initialize(asg_name, region, asg_resource = nil, waiter = nil)
        @region = region
        @asg_name = asg_name
        @asg_resource = asg_resource ||
            Aws::AutoScaling::Resource.new(region: region)
        @asg = @asg_resource.group(@asg_name)
        record_latest_scaling_activity

        @waiter = waiter || Wait.new(attempts: 300, timeout: 30, delay: 5)
      end

      def reload
        @asg.reload
      end

      def name
        @asg_name
      end

      def desired_capacity
        @asg.desired_capacity
      end

      def desired_capacity=(capacity)
        @asg.set_desired_capacity({desired_capacity: capacity})
      end

      def scaling_activities
        @asg.activities.collect {|a| ScalingActivity.new(a)}
      end

      def hosts
        @asg.instances.collect {|h| Host.new(h)}
      end

      def increase_capacity_by(capacity_delta, &block)
        initial = desired_capacity
        increased = initial + capacity_delta

        callbacks_for(block).try_respond_with(
            :prepare, initial, increased)

        ensure_capacity(increased, &block)
      end

      def decrease_capacity_by(capacity_delta, &block)
        initial = desired_capacity
        decreased = initial - capacity_delta

        callbacks_for(block).try_respond_with(
            :prepare, initial, decreased)

        ensure_capacity(decreased, &block)
      end

      def ensure_capacity(capacity, &block)
        self.desired_capacity = capacity
        wait_for_capacity_change_start(&block)
        wait_for_capacity_change_end(&block)
        wait_for_capacity_health(&block)
        record_latest_scaling_activity
      end

      def wait_for_capacity_change_start(&block)
        @waiter.until do |attempt|
          reload
          callbacks_for(block)
              .try_respond_with(:waiting_for_start, attempt) if block
          has_started_changing_capacity?
        end
      end

      def wait_for_capacity_change_end(&block)
        @waiter.until do |attempt|
          reload
          callbacks_for(block)
              .try_respond_with(:waiting_for_complete, attempt) if block
          has_completed_changing_capacity?
        end
      end

      def wait_for_capacity_health(&block)
        @waiter.until do |attempt|
          reload
          callbacks_for(block)
              .try_respond_with(:waiting_for_health, attempt) if block
          has_desired_capacity?
        end
      end

      def record_latest_scaling_activity
        @last_scaling_activity = scaling_activities.first
      end

      def has_started_changing_capacity?
        scaling_activities
            .select {|a| a.started_after_completion_of?(@last_scaling_activity)}
            .size > 0
      end

      def has_completed_changing_capacity?
        scaling_activities.all? {|a| a.is_complete?}
      end

      def has_desired_capacity?
        hosts.size == desired_capacity &&
            hosts.all? {|h| h.is_in_service? && h.is_healthy?}
      end

      private

      def callbacks_for(block)
        Hollerback::Callbacks.new(block)
      end
    end
  end
end
