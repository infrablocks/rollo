# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Rollo::Model::Service do
  describe 'attributes' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'exposes the underlying ECS service name' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_name = 'some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [{ services: [{ service_name: ecs_service_name }] }]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :describe_services }
          .first[:params])
        .to(eq(cluster: ecs_cluster_name, services: [ecs_service_arn]))
      expect(service.name).to(eq(ecs_service_name))
    end
    # rubocop:enable RSpec/MultipleExpectations

    it 'exposes the running count from the underlying ECS service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [{ services: [{ running_count: 6 }] }]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      expect(service.running_count).to(eq(6))
    end

    it 'exposes the desired count from the underlying ECS service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [{ services: [{ desired_count: 6 }] }]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      expect(service.desired_count).to(eq(6))
    end
  end

  describe '#desired_count=' do
    it 'sets the desired count of the underlying service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [{ services: [{ desired_count: 3 }] }]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      service.desired_count = 6

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :update_service }
          .first[:params])
        .to(eq(
              cluster: ecs_cluster_name,
              service: ecs_service_arn,
              desired_count: 6
            ))
    end
  end

  describe '#desired_count_met?' do
    it 'is true if running count equals desired count' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [{ services: [{ running_count: 3, desired_count: 3 }] }]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      expect(service.desired_count_met?).to(be(true))
    end

    it 'is false if running count is different to desired count' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [{ services: [{ running_count: 3, desired_count: 6 }] }]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      expect(service.desired_count_met?).to(be(false))
    end
  end

  describe '#replica?' do
    it 'is true if the scheduling strategy is REPLICA' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [{ services: [{ scheduling_strategy: 'REPLICA' }] }]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      expect(service.replica?).to(be(true))
    end

    it 'is false if the scheduling strategy is DAEMON' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [{ services: [{ scheduling_strategy: 'DAEMON' }] }]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      expect(service.replica?).to(be(false))
    end
  end

  describe '#reload' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'reloads the underlying ECS service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 3, desired_count: 3 }] },
          { services: [{ running_count: 6, desired_count: 9 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource
      )

      service.reload

      expect(service.instance.running_count).to(eq(6))
      expect(service.instance.desired_count).to(eq(9))
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  describe '#ensure_desired_count' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'sets desired count and waits for the service to become healthy' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 3, desired_count: 3 }] },
          { services: [{ running_count: 6, desired_count: 9 }] },
          { services: [{ running_count: 9, desired_count: 9 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      service.ensure_instance_count(9)

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :update_service }
          .first[:params])
        .to(eq(
              cluster: ecs_cluster_name,
              service: ecs_service_arn,
              desired_count: 9
            ))
      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :describe_services }
          .map { |r| r[:params] })
        .to(eq([
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] }
               ]))
    end
    # rubocop:enable RSpec/MultipleExpectations

    it 'reports health check attempts using the provided block' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 3, desired_count: 3 }] },
          { services: [{ running_count: 6, desired_count: 9 }] },
          { services: [{ running_count: 9, desired_count: 9 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      attempts = []
      service.ensure_instance_count(9) do |on|
        on.waiting_for_health do |attempt|
          attempts << attempt
        end
      end

      expect(attempts).to(eq([1, 2]))
    end
  end

  describe '#increase_instance_count_by' do
    # rubocop:disable RSpec/MultipleExpectations
    it('increases the desired count by the requested amount and waits for ' \
       'the service to become healthy') do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 3, desired_count: 3 }] },
          { services: [{ running_count: 6, desired_count: 9 }] },
          { services: [{ running_count: 9, desired_count: 9 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      service.increase_instance_count_by(6)

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :update_service }
          .first[:params])
        .to(eq(
              cluster: ecs_cluster_name,
              service: ecs_service_arn,
              desired_count: 9
            ))
      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :describe_services }
          .map { |r| r[:params] })
        .to(eq([
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] }
               ]))
    end
    # rubocop:enable RSpec/MultipleExpectations

    # rubocop:disable RSpec/MultipleExpectations
    it('honours the specified maximum capacity when supplied') do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 6, desired_count: 6 }] },
          { services: [{ running_count: 6, desired_count: 9 }] },
          { services: [{ running_count: 9, desired_count: 9 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      service.increase_instance_count_by(
        6, maximum_instance_count: 9
      )

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :update_service }
          .first[:params])
        .to(eq(
              cluster: ecs_cluster_name,
              service: ecs_service_arn,
              desired_count: 9
            ))
      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :describe_services }
          .map { |r| r[:params] })
        .to(eq([
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] }
               ]))
    end
    # rubocop:enable RSpec/MultipleExpectations

    it 'reports on start of instance count change using provided block' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 3, desired_count: 3 }] },
          { services: [{ running_count: 6, desired_count: 9 }] },
          { services: [{ running_count: 9, desired_count: 9 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      increase_details = []
      service.increase_instance_count_by(6) do |on|
        on.prepare do |initial, increased|
          increase_details << initial << increased
        end
      end

      expect(increase_details).to(eq([3, 9]))
    end

    it 'reports health check attempts using the provided block' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 3, desired_count: 3 }] },
          { services: [{ running_count: 6, desired_count: 9 }] },
          { services: [{ running_count: 9, desired_count: 9 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      attempts = []
      service.increase_instance_count_by(6) do |on|
        on.waiting_for_health do |attempt|
          attempts << attempt
        end
      end

      expect(attempts).to(eq([1, 2]))
    end
  end

  describe '#decrease_instance_count_by' do
    # rubocop:disable RSpec/MultipleExpectations
    it('decreases the desired count by the requested amount and waits for ' \
       'the service to become healthy') do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 9, desired_count: 9 }] },
          { services: [{ running_count: 6, desired_count: 3 }] },
          { services: [{ running_count: 3, desired_count: 3 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      service.decrease_instance_count_by(6)

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :update_service }
          .first[:params])
        .to(eq(
              cluster: ecs_cluster_name,
              service: ecs_service_arn,
              desired_count: 3
            ))
      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :describe_services }
          .map { |r| r[:params] })
        .to(eq([
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] }
               ]))
    end
    # rubocop:enable RSpec/MultipleExpectations

    # rubocop:disable RSpec/MultipleExpectations
    it('honours the specified minimum capacity when supplied') do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 9, desired_count: 9 }] },
          { services: [{ running_count: 9, desired_count: 6 }] },
          { services: [{ running_count: 6, desired_count: 6 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      service.decrease_instance_count_by(
        6, minimum_instance_count: 6
      )

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :update_service }
          .first[:params])
        .to(eq(
              cluster: ecs_cluster_name,
              service: ecs_service_arn,
              desired_count: 6
            ))
      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :describe_services }
          .map { |r| r[:params] })
        .to(eq([
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] },
                 { cluster: ecs_cluster_name, services: [ecs_service_arn] }
               ]))
    end
    # rubocop:enable RSpec/MultipleExpectations

    it 'reports on start of instance count change using provided block' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 9, desired_count: 9 }] },
          { services: [{ running_count: 6, desired_count: 3 }] },
          { services: [{ running_count: 3, desired_count: 3 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      increase_details = []
      service.decrease_instance_count_by(6) do |on|
        on.prepare do |initial, increased|
          increase_details << initial << increased
        end
      end

      expect(increase_details).to(eq([9, 3]))
    end

    it 'reports health check attempts using the provided block' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_services,
        [
          { services: [{ running_count: 9, desired_count: 9 }] },
          { services: [{ running_count: 6, desired_count: 3 }] },
          { services: [{ running_count: 3, desired_count: 3 }] }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = described_class.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter
      )

      attempts = []
      service.decrease_instance_count_by(6) do |on|
        on.waiting_for_health do |attempt|
          attempts << attempt
        end
      end

      expect(attempts).to(eq([1, 2]))
    end
  end
end
