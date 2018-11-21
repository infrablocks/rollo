module Rollo
  module Model
    class ScalingActivity
      def initialize(activity)
        @activity = activity
      end

      def id
        @activity.activity_id
      end

      def start_time
        @activity.start_time
      end

      def end_time
        @activity.end_time
      end

      def started_after_completion_of?(other)
        self.id != other.id &&
            !self.start_time.nil? &&
            !other.end_time.nil? &&
            self.start_time > other.end_time
      end

      def is_complete?
        %w(Successful Failed Cancelled).include?(@activity.status_code)
      end
    end
  end
end
