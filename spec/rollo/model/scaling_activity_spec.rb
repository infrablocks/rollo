# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Rollo::Model::ScalingActivity do
  it 'exposes the underlying activity ID' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(activity_id, region:)

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.id).to(eq(activity_id))
  end

  it 'exposes the start time of the underlying activity' do
    region = 'eu-west-2'
    start_time = Time.now
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
      activity_id, region:, data: { start_time: }
    )

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.start_time).to(eq(start_time))
  end

  it 'exposes the end time of the underlying activity' do
    region = 'eu-west-2'
    end_time = Time.now
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
      activity_id, region:, data: { end_time: }
    )

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.end_time).to(eq(end_time))
  end

  it('started after other if they have different IDs, it has a start time ' \
     'and the other has an end time and the start time is after the ' \
     'end time') do
    region = 'eu-west-2'

    activity1_end_time = Time.now - 30
    activity1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity1 = Aws::AutoScaling::Activity.new(
      activity1_id, region:, data: { end_time: activity1_end_time }
    )
    scaling_activity1 = described_class.new(activity1)

    activity2_start_time = Time.now + 30
    activity2_id = '0bec5b33-5ca6-4a4b-9de7-6a02f0d1c222'
    activity2 = Aws::AutoScaling::Activity.new(
      activity2_id, region:, data: { start_time: activity2_start_time }
    )
    scaling_activity2 = described_class.new(activity2)

    expect(scaling_activity2.started_after_completion_of?(scaling_activity1))
      .to(be(true))
  end

  it 'did not start after other if IDs are the same' do
    region = 'eu-west-2'

    activity1_end_time = Time.now - 30
    activity1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity1 = Aws::AutoScaling::Activity.new(
      activity1_id, region:, data: { end_time: activity1_end_time }
    )
    scaling_activity1 = described_class.new(activity1)

    activity2_start_time = Time.now + 30
    activity2_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity2 = Aws::AutoScaling::Activity.new(
      activity2_id, region:, data: { start_time: activity2_start_time }
    )
    scaling_activity2 = described_class.new(activity2)

    expect(scaling_activity2.started_after_completion_of?(scaling_activity1))
      .to(be(false))
  end

  it 'did not start after other if it does not have a start time' do
    region = 'eu-west-2'

    activity1_end_time = Time.now - 30
    activity1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity1 = Aws::AutoScaling::Activity.new(
      activity1_id, region:, data: { end_time: activity1_end_time }
    )
    scaling_activity1 = described_class.new(activity1)

    activity2_id = '0bec5b33-5ca6-4a4b-9de7-6a02f0d1c222'
    activity2 = Aws::AutoScaling::Activity.new(
      activity2_id, region:, data: { start_time: nil }
    )
    scaling_activity2 = described_class.new(activity2)

    expect(scaling_activity2.started_after_completion_of?(scaling_activity1))
      .to(be(false))
  end

  it 'did not start after other if other does not have an end time' do
    region = 'eu-west-2'

    activity1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity1 = Aws::AutoScaling::Activity.new(
      activity1_id, region:, data: { end_time: nil }
    )
    scaling_activity1 = described_class.new(activity1)

    activity2_start_time = Time.now + 30
    activity2_id = '0bec5b33-5ca6-4a4b-9de7-6a02f0d1c222'
    activity2 = Aws::AutoScaling::Activity.new(
      activity2_id, region:, data: { start_time: activity2_start_time }
    )
    scaling_activity2 = described_class.new(activity2)

    expect(scaling_activity2.started_after_completion_of?(scaling_activity1))
      .to(be(false))
  end

  it('did not start after other if end time of other is after its ' \
     'start time') do
    region = 'eu-west-2'

    activity1_end_time = Time.now + 30
    activity1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity1 = Aws::AutoScaling::Activity.new(
      activity1_id, region:, data: { end_time: activity1_end_time }
    )
    scaling_activity1 = described_class.new(activity1)

    activity2_start_time = Time.now - 30
    activity2_id = '0bec5b33-5ca6-4a4b-9de7-6a02f0d1c222'
    activity2 = Aws::AutoScaling::Activity.new(
      activity2_id, region:, data: { start_time: activity2_start_time }
    )
    scaling_activity2 = described_class.new(activity2)

    expect(scaling_activity2.started_after_completion_of?(scaling_activity1))
      .to(be(false))
  end

  it 'is complete if it has status code Successful' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
      activity_id, region:, data: { status_code: 'Successful' }
    )

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.complete?).to(be(true))
  end

  it 'is complete if it has status code Failed' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
      activity_id, region:, data: { status_code: 'Failed' }
    )

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.complete?).to(be(true))
  end

  it 'is complete if it has status code Cancelled' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
      activity_id, region:, data: { status_code: 'Cancelled' }
    )

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.complete?).to(be(true))
  end

  it 'is not complete if it has status code InProgress' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
      activity_id, region:, data: { status_code: 'InProgress' }
    )

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.complete?).to(be(false))
  end

  it 'is not complete if it has status code PreInService' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
      activity_id, region:, data: { status_code: 'PreInService' }
    )

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.complete?).to(be(false))
  end

  it 'is not complete if it has status code WaitingForInstanceId' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
      activity_id,
      region:, data: { status_code: 'WaitingForInstanceId' }
    )

    scaling_activity = described_class.new(activity)

    expect(scaling_activity.complete?).to(be(false))
  end
end
