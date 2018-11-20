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
end
