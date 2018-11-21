require_relative '../../spec_helper'

RSpec.describe Rollo::Model::Service do
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
    ecs_service_t1 = Aws::ECS::Types::Service.new(running_count: 3)
    ecs_service_t2 = Aws::ECS::Types::Service.new(running_count: 6)

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

    expect(service.running_count).to(eq(6))
  end

  it 'exposes the desired count from the underlying ECS service' do
    region = 'eu-west-1'
    ecs_cluster_name = 'some-ecs-cluster'
    ecs_service_arn = 'aws:1234:ecs-service/some-ecs-service-name'
    ecs_service_t1 = Aws::ECS::Types::Service.new(desired_count: 3)
    ecs_service_t2 = Aws::ECS::Types::Service.new(desired_count: 6)

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

    expect(service.desired_count).to(eq(6))
  end

  it 'allows the desired count to be set' do
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

  it 'has desired count if running count equals desired count' do
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

  it('does not have desired count if running count is different to ' +
      'desired count') do
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

  it 'is a replica if the scheduling strategy is REPLICA' do
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

  it 'is not a replica if the scheduling strategy is DAEMON' do
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

  it 'reloads the underlying ECS service on reload' do
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

  it('sets desired count and waits for the service to become healthy on ' +
      'ensure desired count') do
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
                ecs_describe_services_response_2,
                ecs_describe_services_response_3,
                ecs_describe_services_response_3))
    allow(ecs_client)
        .to(receive(:update_service)
            .with(
                cluster: ecs_cluster_name,
                service: ecs_service_arn,
                desired_count: 6))

    waiter = Wait.new(attempts: 10, timeout: 10, delay: 1)

    service = Rollo::Model::Service.new(
        ecs_cluster_name, ecs_service_arn, region, ecs_resource, waiter)

    service.ensure_instance_count(6)

    expect(ecs_client)
        .to(have_received(:describe_services)
            .exactly(5).times)
  end
end
