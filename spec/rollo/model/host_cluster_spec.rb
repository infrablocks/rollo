# frozen_string_literal: true

require 'securerandom'
require_relative '../../spec_helper'

def auto_scaling_group_data(asg_name, overrides_and_extras = {})
  {
    auto_scaling_group_name: asg_name,
    min_size: 3,
    max_size: 9,
    desired_capacity: 6,
    default_cooldown: 300,
    availability_zones: %w[eu-west-1a eu-west-1b],
    health_check_type: 'EC2',
    created_time: Time.now
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
    actual.instance_of?(Aws::AutoScaling::Activity) && actual.id == id
  end
end

RSpec::Matchers.define :an_instance_with_id do |id|
  match do |actual|
    actual.instance_of?(Aws::AutoScaling::Instance) && actual.id == id
  end
end

# rubocop:disable RSpec/ExampleLength
# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe Rollo::Model::HostCluster do
  describe 'attributes' do
    it 'exposes the underlying auto scaling group name' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

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
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      desired_capacity = host_cluster.desired_capacity

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :describe_auto_scaling_groups }
             .first[:params])
        .to(eq({ auto_scaling_group_names: [asg_name] }))
      expect(desired_capacity).to(eq(6))
    end

    it 'exposes the scaling activities of the underlying auto scaling group' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          {
            activities: [
              activity_data(asg_name, activity_id: activity1_id),
              activity_data(asg_name, activity_id: activity2_id)
            ]
          }
        ]
      )

      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      scaling_activity1 = double('scaling activity 1')
      scaling_activity2 = double('scaling activity 2')

      allow(Rollo::Model::ScalingActivity)
        .to(receive(:new)
              .with(an_activity_with_id(activity1_id))
              .and_return(scaling_activity1))
      allow(Rollo::Model::ScalingActivity)
        .to(receive(:new)
              .with(an_activity_with_id(activity2_id))
              .and_return(scaling_activity2))

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      scaling_activities = host_cluster.scaling_activities

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :describe_scaling_activities }
             .map { |r| r[:params] })
        .to(eq([
                 { auto_scaling_group_name: asg_name },
                 { auto_scaling_group_name: asg_name }
               ]))
      expect(scaling_activities)
        .to(eq([scaling_activity1, scaling_activity2]))
    end

    it 'exposes the hosts in the underlying auto scaling group' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                instances: [
                  instance_data(instance_id: instance1_id),
                  instance_data(instance_id: instance2_id)
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host1 = double('host 1')
      host2 = double('host 2')

      allow(Rollo::Model::Host)
        .to(receive(:new)
              .with(an_instance_with_id(instance1_id))
              .and_return(host1))
      allow(Rollo::Model::Host)
        .to(receive(:new)
              .with(an_instance_with_id(instance2_id))
              .and_return(host2))

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      hosts = host_cluster.hosts

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :describe_auto_scaling_groups }
             .map { |r| r[:params] })
        .to(eq([
                 { auto_scaling_group_names: [asg_name] }
               ]))
      expect(hosts).to(eq([host1, host2]))
    end
  end

  describe '#reload' do
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
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      initial_desired_capacity = host_cluster.desired_capacity
      host_cluster.reload
      updated_desired_capacity = host_cluster.desired_capacity

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :describe_auto_scaling_groups }
             .map { |r| r[:params] })
        .to(eq([
                 { auto_scaling_group_names: [asg_name] },
                 { auto_scaling_group_names: [asg_name] }
               ]))
      expect(initial_desired_capacity).to(eq(6))
      expect(updated_desired_capacity).to(eq(9))
    end
  end

  describe '#desired_capacity=' do
    it 'sets the desired capacity of the underlying auto scaling group' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      host_cluster.desired_capacity = 6

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :set_desired_capacity }
             .first[:params])
        .to(eq(
              auto_scaling_group_name: asg_name,
              desired_capacity: 6
            ))
    end
  end

  describe '#desired_capacity?' do
    it('returns true when the number of hosts equals the desired capacity ' \
       'and all hosts are healthy and in service') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      expect(host_cluster.desired_capacity?).to(be(true))
    end

    it('returns false when the number of hosts does not equal the ' \
       'desired capacity') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 6,
                instances: [
                  instance_data(instance_id: instance1_id),
                  instance_data(instance_id: instance2_id),
                  instance_data(instance_id: instance3_id)
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      expect(host_cluster.desired_capacity?).to(be(false))
    end

    it('returns false when the any of the hosts is not in service') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'Pending',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      expect(host_cluster.desired_capacity?).to(be(false))
    end

    it('returns false when the any of the hosts is not healthy') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Unhealthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      expect(host_cluster.desired_capacity?).to(be(false))
    end
  end

  describe '#started_changing_capacity?' do
    it('returns true when there is a scaling activity that started after ' \
       'the last recorded completed activity') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid
      activity3_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60
      activity3_start = Time.now
      activity3_end = nil

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: activity3_end
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      expect(host_cluster.started_changing_capacity?).to(be(true))
    end

    it('returns false when no scaling activity has started since ' \
       'the last recorded completed activity') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      expect(host_cluster.started_changing_capacity?).to(be(false))
    end
  end

  describe '#completed_changing_capacity?' do
    it 'returns true when all scaling activities are complete' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid
      activity3_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60
      activity3_start = Time.now - 30
      activity3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: activity3_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      expect(host_cluster.completed_changing_capacity?).to(be(true))
    end

    it 'returns false when any scaling activity is incomplete' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid
      activity3_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60
      activity3_start = Time.now
      activity3_end = nil

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: activity3_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      host_cluster = described_class.new(
        asg_name, region, as_resource
      )

      expect(host_cluster.completed_changing_capacity?).to(be(false))
    end
  end

  describe '#wait_for_capacity_change_start' do
    it 'returns once a capacity change has started' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid
      activity3_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60
      activity3_start = Time.now - 30
      activity3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Second call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Third call is on second call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: activity3_end
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      host_cluster.wait_for_capacity_change_start

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :describe_scaling_activities }
             .length)
        .to(eq(3))
    end

    it('raises exception if no capacity change happens within the specified ' \
       'number of attempts') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Second call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Third call is on second call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 2, timeout: 1, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      expect do
        host_cluster.wait_for_capacity_change_start
      end.to(raise_error(Wait::ResultInvalid))
    end

    it 'reports attempts using the provided block' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid
      activity3_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60
      activity3_start = Time.now - 30
      activity3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Second call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Third call is on second call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: activity3_end
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_attempts = []
      host_cluster.wait_for_capacity_change_start do |on|
        on.waiting_for_start do |attempt|
          found_attempts << attempt
        end
      end

      expect(found_attempts).to(eq([1, 2]))
    end
  end

  describe '#wait_for_capacity_change_end' do
    it 'returns once the capacity change has completed' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid
      activity3_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60
      activity3_start = Time.now - 30
      activity3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on first call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: nil,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on second call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: activity3_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      host_cluster.wait_for_capacity_change_end

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :describe_scaling_activities }
             .length)
        .to(eq(3))
    end

    it('raises exception if the capacity change does not complete within the ' \
       'specified number of attempts') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid
      activity3_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60
      activity3_start = Time.now - 30

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end
              )
            ]
          },
          { # Second call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: nil,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on second call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: nil,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 2, timeout: 1, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      expect do
        host_cluster.wait_for_capacity_change_end
      end.to(raise_error(Wait::ResultInvalid))
    end

    it 'reports attempts using the provided block' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid
      activity3_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 300
      activity2_end = Time.now - 60
      activity3_start = Time.now - 30
      activity3_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on first call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: nil,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on second call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity3_id,
                start_time: activity3_start,
                end_time: activity3_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_attempts = []
      host_cluster.wait_for_capacity_change_end do |on|
        on.waiting_for_end do |attempt|
          found_attempts << attempt
        end
      end

      expect(found_attempts).to(eq([1, 2]))
    end
  end

  describe '#wait_for_capacity_health' do
    it 'returns once the capacity change has completed' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'Pending',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      host_cluster.wait_for_capacity_health

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :describe_auto_scaling_groups }
             .length)
        .to(eq(3))
    end

    it('raises exception if the capacity change does not complete within the ' \
       'specified number of attempts') do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'Pending',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'Pending',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 2, timeout: 1, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      expect do
        host_cluster.wait_for_capacity_health
      end.to(raise_error(Wait::ResultInvalid))
    end

    it 'reports attempts using the provided block' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'Pending',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_attempts = []
      host_cluster.wait_for_capacity_health do |on|
        on.waiting_for_health do |attempt|
          found_attempts << attempt
        end
      end

      expect(found_attempts).to(eq([1, 2, 3]))
    end
  end

  describe '#ensure_capacity_changed_to' do
    it 'sets the desired capacity to the specified value' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      host_cluster.ensure_capacity_changed_to(3)

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :set_desired_capacity }
             .first[:params])
        .to(eq(
              auto_scaling_group_name: asg_name,
              desired_capacity: 3
            ))
    end

    it 'waits for the capacity change to start and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on second call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Fourth call is on call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_started_check_attempts = []
      host_cluster.ensure_capacity_changed_to(3) do |on|
        on.waiting_for_start do |attempt|
          found_started_check_attempts << attempt
        end
      end

      expect(found_started_check_attempts).to(eq([1, 2]))
    end

    it 'waits for the capacity change to complete and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Fourth call is on second call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_completed_check_attempts = []
      host_cluster.ensure_capacity_changed_to(3) do |on|
        on.waiting_for_end do |attempt|
          found_completed_check_attempts << attempt
        end
      end

      expect(found_completed_check_attempts).to(eq([1, 2]))
    end

    it 'waits for capacity health and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          { # First call on call of reload in
            # #wait_for_capacity_change_start
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 2,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Second call on call of reload in
            # #wait_for_capacity_change_end
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 2,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Third call on first call of reload in
            # #wait_for_capacity_health
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'Pending',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Third call on first call of reload in
            # #wait_for_capacity_health
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_completed_check_attempts = []
      host_cluster.ensure_capacity_changed_to(6) do |on|
        on.waiting_for_health do |attempt|
          found_completed_check_attempts << attempt
        end
      end

      expect(found_completed_check_attempts).to(eq([1, 2]))
    end

    it 'records the last scaling activity' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      expect(host_cluster.last_scaling_activity.id)
        .to(eq(activity1_id))

      host_cluster.ensure_capacity_changed_to(3)

      expect(host_cluster.last_scaling_activity.id)
        .to(eq(activity2_id))
    end
  end

  describe '#increase_capacity_by' do
    it 'notifies of the capacity change using the provided block' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      increase_details = []
      host_cluster.increase_capacity_by(3) do |on|
        on.prepare do |before, after|
          increase_details << before << after
        end
      end

      expect(increase_details).to(eq([3, 6]))
    end

    it 'increases the desired capacity by the specified amount' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      host_cluster.increase_capacity_by(3)

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :set_desired_capacity }
             .first[:params])
        .to(eq(
              auto_scaling_group_name: asg_name,
              desired_capacity: 6
            ))
    end

    it 'waits for the capacity change to start and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on second call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Fourth call is on call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_started_check_attempts = []
      host_cluster.increase_capacity_by(3) do |on|
        on.waiting_for_start do |attempt|
          found_started_check_attempts << attempt
        end
      end

      expect(found_started_check_attempts).to(eq([1, 2]))
    end

    it 'waits for the capacity change to complete and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Fourth call is on second call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_completed_check_attempts = []
      host_cluster.increase_capacity_by(1) do |on|
        on.waiting_for_end do |attempt|
          found_completed_check_attempts << attempt
        end
      end

      expect(found_completed_check_attempts).to(eq([1, 2]))
    end

    it 'waits for capacity health and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          { # First call gets desired capacity
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 2,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Second call on call of reload in
            # #wait_for_capacity_change_start
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 2,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Third call on call of reload in
            # #wait_for_capacity_change_end
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 2,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Fourth call on first call of reload in
            # #wait_for_capacity_health
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'Pending',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Fifth call on first call of reload in
            # #wait_for_capacity_health
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_completed_check_attempts = []
      host_cluster.increase_capacity_by(1) do |on|
        on.waiting_for_health do |attempt|
          found_completed_check_attempts << attempt
        end
      end

      expect(found_completed_check_attempts).to(eq([1, 2]))
    end

    it 'records the last scaling activity' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      expect(host_cluster.last_scaling_activity.id)
        .to(eq(activity1_id))

      host_cluster.increase_capacity_by(1)

      expect(host_cluster.last_scaling_activity.id)
        .to(eq(activity2_id))
    end
  end

  describe '#decrease_capacity_by' do
    it 'notifies of the capacity change using the provided block' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      increase_details = []
      host_cluster.decrease_capacity_by(1) do |on|
        on.prepare do |before, after|
          increase_details << before << after
        end
      end

      expect(increase_details).to(eq([3, 2]))
    end

    it 'decreases the desired capacity by the specified amount' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      host_cluster.decrease_capacity_by(1)

      expect(as_client.api_requests
             .select { |r| r[:operation_name] == :set_desired_capacity }
             .first[:params])
        .to(eq(
              auto_scaling_group_name: asg_name,
              desired_capacity: 2
            ))
    end

    it 'waits for the capacity change to start and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on second call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Fourth call is on call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_started_check_attempts = []
      host_cluster.decrease_capacity_by(1) do |on|
        on.waiting_for_start do |attempt|
          found_started_check_attempts << attempt
        end
      end

      expect(found_started_check_attempts).to(eq([1, 2]))
    end

    it 'waits for the capacity change to complete and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on first call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Fourth call is on second call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_completed_check_attempts = []
      host_cluster.decrease_capacity_by(1) do |on|
        on.waiting_for_end do |attempt|
          found_completed_check_attempts << attempt
        end
      end

      expect(found_completed_check_attempts).to(eq([1, 2]))
    end

    it 'waits for capacity health and reports attempts' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of
            # #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of
            # #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          { # First call gets desired capacity
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Second call on call of reload in
            # #wait_for_capacity_change_start
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Third call on call of reload in
            # #wait_for_capacity_change_end
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Fourth call on first call of reload in
            # #wait_for_capacity_health
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 2,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'Terminating',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          },
          { # Fifth call on first call of reload in
            # #wait_for_capacity_health
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 2,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      found_completed_check_attempts = []
      host_cluster.decrease_capacity_by(1) do |on|
        on.waiting_for_health do |attempt|
          found_completed_check_attempts << attempt
        end
      end

      expect(found_completed_check_attempts).to(eq([1, 2]))
    end

    it 'records the last scaling activity' do
      region = 'eu-west-1'
      asg_name = 'some-auto-scaling-group'

      instance1_id = 'i-abcdef1234567891'
      instance2_id = 'i-abcdef1234567892'
      instance3_id = 'i-abcdef1234567893'

      activity1_id = SecureRandom.uuid
      activity2_id = SecureRandom.uuid

      activity1_start = Time.now - 360
      activity1_end = Time.now - 120
      activity2_start = Time.now - 60
      activity2_end = Time.now

      as_client = Aws::AutoScaling::Client.new(stub_responses: true)
      as_client.stub_responses(
        :describe_scaling_activities,
        [
          { # First call is on creation
            activities: [
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Second call is on call of #started_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'InProgress'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          },
          { # Third call is on call of #completed_changing_capacity?
            activities: [
              activity_data(
                asg_name,
                activity_id: activity2_id,
                start_time: activity2_start,
                end_time: activity2_end,
                status_code: 'Successful'
              ),
              activity_data(
                asg_name,
                activity_id: activity1_id,
                start_time: activity1_start,
                end_time: activity1_end,
                status_code: 'Successful'
              )
            ]
          }
        ]
      )
      as_client.stub_responses(
        :describe_auto_scaling_groups,
        [
          {
            auto_scaling_groups: [
              auto_scaling_group_data(
                asg_name,
                desired_capacity: 3,
                instances: [
                  instance_data(
                    instance_id: instance1_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance2_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  ),
                  instance_data(
                    instance_id: instance3_id,
                    lifecycle_state: 'InService',
                    health_status: 'Healthy'
                  )
                ]
              )
            ]
          }
        ]
      )
      as_resource = Aws::AutoScaling::Resource.new(client: as_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      host_cluster = described_class.new(
        asg_name, region, as_resource, waiter
      )

      expect(host_cluster.last_scaling_activity.id)
        .to(eq(activity1_id))

      host_cluster.decrease_capacity_by(1)

      expect(host_cluster.last_scaling_activity.id)
        .to(eq(activity2_id))
    end
  end
end
# rubocop:enable RSpec/ExampleLength
# rubocop:enable RSpec/VerifiedDoubles
