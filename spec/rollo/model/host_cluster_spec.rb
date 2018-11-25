require 'securerandom'
require_relative '../../spec_helper'

def auto_scaling_group_data(asg_name, overrides_and_extras = {})
  {
      auto_scaling_group_name: asg_name,
      min_size: 3,
      max_size: 9,
      desired_capacity: 6,
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

def instance_data(overrides_and_extras = {})
  {
      instance_id: "i-abcdef123456789#{Random.rand(100)}",
      availability_zone: 'eu-west-1a',
      lifecycle_state: 'InService',
      health_status: 'Healthy',
      protected_from_scale_in: false
  }.merge(overrides_and_extras)
end

RSpec::Matchers.define :an_activity_with_id do |id|
  match do |actual|
    actual.class == Aws::AutoScaling::Activity && actual.id == id
  end
end

RSpec::Matchers.define :an_instance_with_id do |id|
  match do |actual|
    actual.class == Aws::AutoScaling::Instance && actual.id == id
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
          .map {|r| r[:params]})
          .to(eq([
              {auto_scaling_group_name: asg_name},
              {auto_scaling_group_name: asg_name},
          ]))
      expect(scaling_activities)
          .to(eq([scaling_activity_1, scaling_activity_2]))
    end

    it 'exposes the hosts in the underlying auto scaling group' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance_1_id = 'i-abcdef1234567891'
      instance_2_id = 'i-abcdef1234567892'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          instances: [
                              instance_data(instance_id: instance_1_id),
                              instance_data(instance_id: instance_2_id),
                          ]
                      )
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_1 = double('host 1')
      host_2 = double('host 2')

      allow(Rollo::Model::Host)
          .to(receive(:new)
              .with(an_instance_with_id(instance_1_id))
              .and_return(host_1))
      allow(Rollo::Model::Host)
          .to(receive(:new)
              .with(an_instance_with_id(instance_2_id))
              .and_return(host_2))

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      hosts = host_cluster.hosts

      expect(as_client.api_requests
          .select {|r| r[:operation_name] == :describe_auto_scaling_groups}
          .map {|r| r[:params]})
          .to(eq([
              {auto_scaling_group_names: [asg_name]},
          ]))
      expect(hosts).to(eq([host_1, host_2]))
    end
  end

  context '#reload' do
    it 'reloads the underlying auto scaling group' do
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
              },
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name, desired_capacity: 9)
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      initial_desired_capacity = host_cluster.desired_capacity
      host_cluster.reload
      updated_desired_capacity = host_cluster.desired_capacity

      expect(as_client.api_requests
          .select {|r| r[:operation_name] == :describe_auto_scaling_groups}
          .map {|r| r[:params]})
          .to(eq([
              {auto_scaling_group_names: [asg_name]},
              {auto_scaling_group_names: [asg_name]}
          ]))
      expect(initial_desired_capacity).to(eq(6))
      expect(updated_desired_capacity).to(eq(9))
    end
  end

  context '#desired_capacity=' do
    it 'sets the desired capacity of the underlying auto scaling group' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      host_cluster.desired_capacity = 6

      expect(as_client.api_requests
          .select {|r| r[:operation_name] == :set_desired_capacity}
          .first[:params])
          .to(eq(
              auto_scaling_group_name: asg_name,
              desired_capacity: 6))
    end
  end

  context '#has_desired_capacity?' do
    it('returns true when the number of hosts equals the desired capacity ' +
        'and all hosts are healthy and in service') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance_1_id = 'i-abcdef1234567891'
      instance_2_id = 'i-abcdef1234567892'
      instance_3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.has_desired_capacity?).to(be(true))
    end

    it('returns false when the number of hosts does not equal the ' +
        'desired capacity') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance_1_id = 'i-abcdef1234567891'
      instance_2_id = 'i-abcdef1234567892'
      instance_3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 6,
                          instances: [
                              instance_data(instance_id: instance_1_id),
                              instance_data(instance_id: instance_2_id),
                              instance_data(instance_id: instance_3_id)
                          ]
                      )
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.has_desired_capacity?).to(be(false))
    end

    it('returns false when the any of the hosts is not in service') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance_1_id = 'i-abcdef1234567891'
      instance_2_id = 'i-abcdef1234567892'
      instance_3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'Pending',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.has_desired_capacity?).to(be(false))
    end

    it('returns false when the any of the hosts is not healthy') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance_1_id = 'i-abcdef1234567891'
      instance_2_id = 'i-abcdef1234567892'
      instance_3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Unhealthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.has_desired_capacity?).to(be(false))
    end
  end

  context '#has_started_changing_capacity?' do
    it('returns true when there is a scaling activity that started after ' +
        'the last recorded completed activity') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid
      activity_3_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60
      activity_3_start = Time.now
      activity_3_end = nil

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Second call is on call of #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: activity_3_end),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.has_started_changing_capacity?).to(eq(true))
    end

    it('returns false when no scaling activity has started since ' +
        'the last recorded completed activity') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Second call is on call of #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.has_started_changing_capacity?).to(eq(false))
    end
  end

  context '#has_completed_changing_capacity?' do
    it 'returns true when all scaling activities are complete' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid
      activity_3_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60
      activity_3_start = Time.now - 30
      activity_3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              },
              { # Second call is on call of #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: activity_3_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.has_completed_changing_capacity?).to(eq(true))
    end

    it 'returns false when any scaling activity is incomplete' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid
      activity_3_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60
      activity_3_start = Time.now
      activity_3_end = nil

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              },
              { # Second call is on call of #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: activity_3_end,
                          status_code: 'InProgress'),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource)

      expect(host_cluster.has_completed_changing_capacity?).to(eq(false))
    end
  end

  context '#wait_for_capacity_change_start' do
    it 'returns once a capacity change has started' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid
      activity_3_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60
      activity_3_start = Time.now - 30
      activity_3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Second call is on first call of
                # #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Third call is on second call of
                # #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: activity_3_end),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      host_cluster.wait_for_capacity_change_start

      expect(as_client.api_requests
          .select {|r| r[:operation_name] == :describe_scaling_activities}
          .length)
          .to(eq(3))
    end

    it('raises exception if no capacity change happens within the specified ' +
        'number of attempts') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Second call is on first call of
                  # #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Third call is on second call of
                  # #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 2, timeout: 1, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      expect {
        host_cluster.wait_for_capacity_change_start
      }.to(raise_error(Wait::ResultInvalid))
    end

    it 'reports attempts using the provided block' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid
      activity_3_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60
      activity_3_start = Time.now - 30
      activity_3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Second call is on first call of
                  # #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Third call is on second call of
                  # #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: activity_3_end),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      found_attempts = []
      host_cluster.wait_for_capacity_change_start do |on|
        on.waiting_for_start do |attempt|
          found_attempts << attempt
        end
      end

      expect(found_attempts).to(eq([1, 2]))
    end
  end

  context '#wait_for_capacity_change_end' do
    it 'returns once the capacity change has completed' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid
      activity_3_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60
      activity_3_start = Time.now - 30
      activity_3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              },
              { # Second call is on first call of
                # #has_completed_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: nil,
                          status_code: 'InProgress'),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              },
              { # Third call is on second call of
                # #has_completed_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: activity_3_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      host_cluster.wait_for_capacity_change_end

      expect(as_client.api_requests
          .select {|r| r[:operation_name] == :describe_scaling_activities}
          .length)
          .to(eq(3))
    end

    it('raises exception if the capacity change does not complete within the ' +
        'specified number of attempts') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid
      activity_3_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60
      activity_3_start = Time.now - 30

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end),
                  ]
              },
              { # Second call is on first call of
                # #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: nil,
                          status_code: 'InProgress'),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful')
                  ]
              },
              { # Third call is on second call of
                # #has_started_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: nil,
                          status_code: 'InProgress'),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful')
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 2, timeout: 1, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      expect {
        host_cluster.wait_for_capacity_change_end
      }.to(raise_error(Wait::ResultInvalid))
    end

    it 'reports attempts using the provided block' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity_1_id = SecureRandom.uuid
      activity_2_id = SecureRandom.uuid
      activity_3_id = SecureRandom.uuid

      activity_1_start = Time.now - 360
      activity_1_end = Time.now - 120
      activity_2_start = Time.now - 300
      activity_2_end = Time.now - 60
      activity_3_start = Time.now - 30
      activity_3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_scaling_activities,
          [
              { # First call is on creation
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              },
              { # Second call is on first call of
                  # #has_completed_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: nil,
                          status_code: 'InProgress'),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              },
              { # Third call is on second call of
                  # #has_completed_changing_capacity?
                  activities: [
                      activity_data(asg_name,
                          activity_id: activity_3_id,
                          start_time: activity_3_start,
                          end_time: activity_3_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_2_id,
                          start_time: activity_2_start,
                          end_time: activity_2_end,
                          status_code: 'Successful'),
                      activity_data(asg_name,
                          activity_id: activity_1_id,
                          start_time: activity_1_start,
                          end_time: activity_1_end,
                          status_code: 'Successful'),
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      found_attempts = []
      host_cluster.wait_for_capacity_change_end do |on|
        on.waiting_for_complete do |attempt|
          found_attempts << attempt
        end
      end

      expect(found_attempts).to(eq([1, 2]))
    end
  end

  context '#wait_for_capacity_health' do
    it 'returns once the capacity change has completed' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance_1_id = 'i-abcdef1234567891'
      instance_2_id = 'i-abcdef1234567892'
      instance_3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              },
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'Pending',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              },
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      host_cluster.wait_for_capacity_health

      expect(as_client.api_requests
          .select {|r| r[:operation_name] == :describe_auto_scaling_groups}
          .length)
          .to(eq(3))
    end

    it('raises exception if the capacity change does not complete within the ' +
        'specified number of attempts') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance_1_id = 'i-abcdef1234567891'
      instance_2_id = 'i-abcdef1234567892'
      instance_3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              },
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'Pending',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              },
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'Pending',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 2, timeout: 1, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      expect {
        host_cluster.wait_for_capacity_health
      }.to(raise_error(Wait::ResultInvalid))
    end

    it 'reports attempts using the provided block' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance_1_id = 'i-abcdef1234567891'
      instance_2_id = 'i-abcdef1234567892'
      instance_3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
          :describe_auto_scaling_groups,
          [
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              },
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'Pending',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              },
              {
                  auto_scaling_groups: [
                      auto_scaling_group_data(asg_name,
                          desired_capacity: 3,
                          instances: [
                              instance_data(
                                  instance_id: instance_1_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_2_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy'),
                              instance_data(
                                  instance_id: instance_3_id,
                                  lifecycle_state: 'InService',
                                  health_status: 'Healthy')
                          ]
                      )
                  ]
              }
          ])
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = Rollo::Model::HostCluster.new(
          asg_name, region, as_resource, waiter)

      found_attempts = []
      host_cluster.wait_for_capacity_health do |on|
        on.waiting_for_health do |attempt|
          found_attempts << attempt
        end
      end

      expect(found_attempts).to(eq([1, 2, 3]))
    end
  end
end
