require_relative '../../spec_helper'

RSpec.describe Rollo::Model::ScalingActivity do
  it 'exposes the underlying activity ID' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(activity_id, region: region)

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.id).to(eq(activity_id))
  end

  it 'exposes the start time of the underlying activity' do
    region = 'eu-west-2'
    start_time = Time.now
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
        activity_id, region: region, data: {start_time: start_time})

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.start_time).to(eq(start_time))
  end

  it 'exposes the end time of the underlying activity' do
    region = 'eu-west-2'
    end_time = Time.now
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
        activity_id, region: region, data: {end_time: end_time})

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.end_time).to(eq(end_time))
  end

  it ('started after other if they have different IDs, it has a start time ' +
      'and the other has an end time and the start time is after the ' +
      'end time') do
    region = 'eu-west-2'

    activity_1_end_time = Time.now - 30
    activity_1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity_1 = Aws::AutoScaling::Activity.new(
        activity_1_id, region: region, data: {end_time: activity_1_end_time})
    scaling_activity_1 = Rollo::Model::ScalingActivity.new(activity_1)

    activity_2_start_time = Time.now + 30
    activity_2_id = '0bec5b33-5ca6-4a4b-9de7-6a02f0d1c222'
    activity_2 = Aws::AutoScaling::Activity.new(
        activity_2_id, region: region, data: {start_time: activity_2_start_time})
    scaling_activity_2 = Rollo::Model::ScalingActivity.new(activity_2)

    expect(scaling_activity_2.started_after_completion_of?(scaling_activity_1))
        .to(be(true))
  end

  it 'did not start after other if IDs are the same' do
    region = 'eu-west-2'

    activity_1_end_time = Time.now - 30
    activity_1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity_1 = Aws::AutoScaling::Activity.new(
        activity_1_id, region: region, data: {end_time: activity_1_end_time})
    scaling_activity_1 = Rollo::Model::ScalingActivity.new(activity_1)

    activity_2_start_time = Time.now + 30
    activity_2_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity_2 = Aws::AutoScaling::Activity.new(
        activity_2_id, region: region, data: {start_time: activity_2_start_time})
    scaling_activity_2 = Rollo::Model::ScalingActivity.new(activity_2)

    expect(scaling_activity_2.started_after_completion_of?(scaling_activity_1))
        .to(be(false))
  end

  it 'did not start after other if it does not have a start time' do
    region = 'eu-west-2'

    activity_1_end_time = Time.now - 30
    activity_1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity_1 = Aws::AutoScaling::Activity.new(
        activity_1_id, region: region, data: {end_time: activity_1_end_time})
    scaling_activity_1 = Rollo::Model::ScalingActivity.new(activity_1)

    activity_2_id = '0bec5b33-5ca6-4a4b-9de7-6a02f0d1c222'
    activity_2 = Aws::AutoScaling::Activity.new(
        activity_2_id, region: region, data: {start_time: nil})
    scaling_activity_2 = Rollo::Model::ScalingActivity.new(activity_2)

    expect(scaling_activity_2.started_after_completion_of?(scaling_activity_1))
        .to(be(false))
  end

  it 'did not start after other if other does not have an end time' do
    region = 'eu-west-2'

    activity_1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity_1 = Aws::AutoScaling::Activity.new(
        activity_1_id, region: region, data: {end_time: nil})
    scaling_activity_1 = Rollo::Model::ScalingActivity.new(activity_1)

    activity_2_start_time = Time.now + 30
    activity_2_id = '0bec5b33-5ca6-4a4b-9de7-6a02f0d1c222'
    activity_2 = Aws::AutoScaling::Activity.new(
        activity_2_id, region: region, data: {start_time: activity_2_start_time})
    scaling_activity_2 = Rollo::Model::ScalingActivity.new(activity_2)

    expect(scaling_activity_2.started_after_completion_of?(scaling_activity_1))
        .to(be(false))
  end

  it ('did not start after other if end time of other is after its ' +
      'start time') do
    region = 'eu-west-2'

    activity_1_end_time = Time.now + 30
    activity_1_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity_1 = Aws::AutoScaling::Activity.new(
        activity_1_id, region: region, data: {end_time: activity_1_end_time})
    scaling_activity_1 = Rollo::Model::ScalingActivity.new(activity_1)

    activity_2_start_time = Time.now - 30
    activity_2_id = '0bec5b33-5ca6-4a4b-9de7-6a02f0d1c222'
    activity_2 = Aws::AutoScaling::Activity.new(
        activity_2_id, region: region, data: {start_time: activity_2_start_time})
    scaling_activity_2 = Rollo::Model::ScalingActivity.new(activity_2)

    expect(scaling_activity_2.started_after_completion_of?(scaling_activity_1))
        .to(be(false))
  end

  it 'is complete if it has status code Successful' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
        activity_id, region: region, data: {status_code: 'Successful'})

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.is_complete?).to(be(true))
  end

  it 'is complete if it has status code Failed' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
        activity_id, region: region, data: {status_code: 'Failed'})

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.is_complete?).to(be(true))
  end

  it 'is complete if it has status code Cancelled' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
        activity_id, region: region, data: {status_code: 'Cancelled'})

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.is_complete?).to(be(true))
  end

  it 'is not complete if it has status code InProgress' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
        activity_id, region: region, data: {status_code: 'InProgress'})

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.is_complete?).to(be(false))
  end

  it 'is not complete if it has status code PreInService' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
        activity_id, region: region, data: {status_code: 'PreInService'})

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.is_complete?).to(be(false))
  end

  it 'is not complete if it has status code WaitingForInstanceId' do
    region = 'eu-west-2'
    activity_id = '6c9714d2-dea0-4580-ab13-9a8dd8ddad8e'
    activity = Aws::AutoScaling::Activity.new(
        activity_id,
        region: region, data: {status_code: 'WaitingForInstanceId'})

    scaling_activity = Rollo::Model::ScalingActivity.new(activity)

    expect(scaling_activity.is_complete?).to(be(false))
  end
end
