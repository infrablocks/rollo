require 'securerandom'
require_relative '../../spec_helper'

def auto_scaling_group_data(asg_name, overrides_and_extras = {})
  {
      auto_scaling_group_name: asg_name,
      min_size: 3,
      max_size: 9,
      default_cooldown: 300,
      availability_zones: ['eu-west-1a', 'eu-west-1b'],
      health_check_type: 'EC2',
      created_time: Time.now,
  }.merge(overrides_and_extras)
end

def activity_data(asg_name, overrides_and_extras = {})
  {
      activity_id: SecureRandom.uuid,
      auto_scaling_group_name: asg_name,
      cause: 'Something happened',
      start_time: Time.now,
      status_code: 'InProgress'
  }.merge(overrides_and_extras)
end

RSpec::Matchers.define :an_activity_with_id do |id|
  match do |actual|
    actual.class == Aws::AutoScaling::Activity && actual.id == id
  end
end

RSpec.describe Rollo::Model::HostCluster do
  context 'attributes' do
    it 'exposes the underlying auto scaling group name' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.name).to(eq(asg_name))
    end

    it 'exposes the desired capacity of the underlying auto scaling group' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name, desired_capacity: 6)
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      desired_capacity = host_cluster.desired_capacity

      expect(as_client.api_requests
          .select {|r| r[:operation_name] == :describe_auto_scaling_groups}
          .first[:params])
          .to(eq({auto_scaling_group_names: [asg_name]}))
      expect(desired_capacity).to(eq(6))
    end

    it 'exposes the scaling activities of the underlying auto scaling group' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name, desired_capacity: 6)
                  ]
              }
          ])
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              {
                  activities: [
                      activity_data(asg_name, activity_id: activity_1_id),
                      activity_data(asg_name, activity_id: activity_2_id),
                  ]
              }
          ])

      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      scaling_activity_1 = double('scaling activity 1')
      scaling_activity_2 = double('scaling activity 2')

      allow(Rollo::Model::ScalingActivity)
          .to(receive(:new)
              .with(an_activity_with_id(activity_1_id))
              .and_return(scaling_activity_1))
      allow(Rollo::Model::ScalingActivity)
          .to(receive(:new)
              .with(an_activity_with_id(activity_2_id))
              .and_return(scaling_activity_2))

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      scaling_activities = host_cluster.scaling_activities

      expect(as_client.api_requests
          .select {|r| r[:operation_name] == :describe_scaling_activities}
          .map {|r| r[:params] })
          .to(eq([
              {auto_scaling_group_name: asg_name},
              {auto_scaling_group_name: asg_name},
          ]))
      expect(scaling_activities)
          .to(eq([scaling_activity_1, scaling_activity_2]))
    end
  end
end
