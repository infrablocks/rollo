require_relative '../../spec_helper'

RSpec.describe Rollo::Model::Service do
  context 'attributes' do
    it 'exposes the underlying ECS service name' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_name = 'some-ecs-service-name'
      ecs_service = Aws::ECS::Types::Service.new(service_name: ecs_service_name)

      ecs_describe_services_response =
          Aws::ECS::Types::DescribeServicesResponse.new(services: [ecs_service])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(ecs_describe_services_response))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      expect(service.name).to(eq(ecs_service_name))
    end

    it 'exposes the running count from the underlying ECS service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service = Aws::ECS::Types::Service.new(running_count: 6)

      ecs_describe_services_response =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      expect(service.running_count).to(eq(6))
    end

    it 'exposes the desired count from the underlying ECS service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service = Aws::ECS::Types::Service.new(desired_count: 6)

      ecs_describe_services_response =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      expect(service.desired_count).to(eq(6))
    end
  end

  context '#desired_count=' do
    it 'sets the desired count of the underlying service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service = Aws::ECS::Types::Service.new(desired_count: 3)

      ecs_describe_services_response =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(ecs_describe_services_response))
      allow(ecs_client).to(receive(:update_service))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      expect(ecs_client)
          .to(receive(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 6))

      service.desired_count = 6
    end
  end

  context '#has_desired_count?' do
    it 'is true if running count equals desired count' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)

      ecs_describe_services_response =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(ecs_describe_services_response))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      expect(service.has_desired_count?).to(be(true))
    end

    it 'is false if running count is different to desired count' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)

      ecs_describe_services_response =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(ecs_describe_services_response))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      expect(service.has_desired_count?).to(be(true))
    end
  end

  context '#is_replica?' do
    it 'is true if the scheduling strategy is REPLICA' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service = Aws::ECS::Types::Service.new(
          scheduling_strategy: 'REPLICA')

      ecs_describe_services_response =
          Aws::ECS::Types::DescribeServicesResponse.new(services: [ecs_service])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(ecs_describe_services_response))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      expect(service.is_replica?).to(be(true))
    end

    it 'is false if the scheduling strategy is DAEMON' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service = Aws::ECS::Types::Service.new(
          scheduling_strategy: 'DAEMON')

      ecs_describe_services_response =
          Aws::ECS::Types::DescribeServicesResponse.new(services: [ecs_service])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(ecs_describe_services_response))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      expect(service.is_replica?).to(be(false))
    end
  end

  context '#reload' do
    it 'reloads the underlying ECS service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 9)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2))

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource)

      service.reload

      expect(service.instance.running_count).to(eq(6))
      expect(service.instance.desired_count).to(eq(9))
    end
  end

  context '#ensure_desired_count' do
    it 'sets desired count and waits for the service to become healthy' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 9)
      ecs_service_t3 = Aws::ECS::Types::Service.new(
          running_count: 9,
          desired_count: 9)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])
      ecs_describe_services_response_3 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t3])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2,
                  ecs_describe_services_response_3))
      allow(ecs_client)
          .to(receive(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 9))

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

      service.ensure_instance_count(9)

      expect(ecs_client)
          .to(have_received(:describe_services)
              .exactly(3).times)
    end

    it 'reports health check attempts using the provided block' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 9)
      ecs_service_t3 = Aws::ECS::Types::Service.new(
          running_count: 9,
          desired_count: 9)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])
      ecs_describe_services_response_3 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t3])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2,
                  ecs_describe_services_response_3))
      allow(ecs_client)
          .to(receive(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 9))

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

      attempts = []
      service.ensure_instance_count(9) do |on|
        on.waiting_for_health do |attempt|
          attempts << attempt
        end
      end

      expect(attempts).to(eq([1, 2]))
    end
  end

  context '#increase_instance_count_by' do
    it('increases the desired count by the requested amount and waits for ' +
        'the service to become healthy') do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 9)
      ecs_service_t3 = Aws::ECS::Types::Service.new(
          running_count: 9,
          desired_count: 9)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])
      ecs_describe_services_response_3 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t3])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2,
                  ecs_describe_services_response_3))
      allow(ecs_client).to(receive(:update_service))

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

      service.increase_instance_count_by(6)

      expect(ecs_client)
          .to(have_received(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 9))
      expect(ecs_client)
          .to(have_received(:describe_services)
              .exactly(3).times)
    end

    it 'reports on start of instance count change using provided block' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 9)
      ecs_service_t3 = Aws::ECS::Types::Service.new(
          running_count: 9,
          desired_count: 9)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])
      ecs_describe_services_response_3 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t3])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2,
                  ecs_describe_services_response_3))
      allow(ecs_client)
          .to(receive(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 9))

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

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
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 9)
      ecs_service_t3 = Aws::ECS::Types::Service.new(
          running_count: 9,
          desired_count: 9)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])
      ecs_describe_services_response_3 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t3])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2,
                  ecs_describe_services_response_3))
      allow(ecs_client)
          .to(receive(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 9))

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

      attempts = []
      service.increase_instance_count_by(6) do |on|
        on.waiting_for_health do |attempt|
          attempts << attempt
        end
      end

      expect(attempts).to(eq([1, 2]))
    end
  end

  context '#decrease_instance_count_by' do
    it('decreases the desired count by the requested amount and waits for ' +
        'the service to become healthy') do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 9,
          desired_count: 9)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 3)
      ecs_service_t3 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])
      ecs_describe_services_response_3 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t3])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2,
                  ecs_describe_services_response_3))
      allow(ecs_client).to(receive(:update_service))

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

      service.decrease_instance_count_by(6)

      expect(ecs_client)
          .to(have_received(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 3))
      expect(ecs_client)
          .to(have_received(:describe_services)
              .exactly(3).times)
    end

    it 'reports on start of instance count change using provided block' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 9,
          desired_count: 9)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 3)
      ecs_service_t3 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])
      ecs_describe_services_response_3 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t3])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2,
                  ecs_describe_services_response_3))
      allow(ecs_client)
          .to(receive(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 3))

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

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
      ecs_service_t1 = Aws::ECS::Types::Service.new(
          running_count: 9,
          desired_count: 9)
      ecs_service_t2 = Aws::ECS::Types::Service.new(
          running_count: 6,
          desired_count: 3)
      ecs_service_t3 = Aws::ECS::Types::Service.new(
          running_count: 3,
          desired_count: 3)

      ecs_describe_services_response_1 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t1])
      ecs_describe_services_response_2 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t2])
      ecs_describe_services_response_3 =
          Aws::ECS::Types::DescribeServicesResponse.new(
              services: [ecs_service_t3])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_services)
              .with(cluster: ecs_cluster_name, services: [ecs_service_arn])
              .and_return(
                  ecs_describe_services_response_1,
                  ecs_describe_services_response_2,
                  ecs_describe_services_response_3))
      allow(ecs_client)
          .to(receive(:update_service)
              .with(
                  cluster: ecs_cluster_name,
                  service: ecs_service_arn,
                  desired_count: 3))

      waiter = Wait.new(attempts: 10, timeout: 10, delay: 0.05)

      service = Rollo::Model::Service.new(
          ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

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
