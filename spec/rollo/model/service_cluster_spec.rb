require 'securerandom'
require_relative '../../spec_helper'

RSpec.describe Rollo::Model::ServiceCluster do
  context 'attributes' do
    it 'exposes the ECS cluster name' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_cluster = Aws::ECS::Types::Cluster.new(cluster_name: ecs_cluster_name)

      ecs_describe_clusters_response =
          Aws::ECS::Types::DescribeClustersResponse.new(clusters: [ecs_cluster])

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_clusters)
              .with(clusters: [ecs_cluster_name])
              .and_return(ecs_describe_clusters_response))

      service_cluster = Rollo::Model::ServiceCluster.new(
          ecs_cluster_name, region, ecs_resource)

      expect(service_cluster.name).to(eq(ecs_cluster_name))
    end

    it 'exposes the replica services in the ECS cluster' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_cluster = Aws::ECS::Types::Cluster.new(cluster_name: ecs_cluster_name)

      ecs_service_arn_1 = 'aws:1234:ecs-service/some-ecs-service-name-1'
      ecs_service_arn_2 = 'aws:1234:ecs-service/some-ecs-service-name-2'
      ecs_service_arn_3 = 'aws:1234:ecs-service/some-ecs-service-name-3'

      ecs_describe_clusters_response =
          Aws::ECS::Types::DescribeClustersResponse.new(clusters: [ecs_cluster])
      ecs_list_services_response_1_next_token = SecureRandom.uuid
      ecs_list_services_response_1 =
          Aws::ECS::Types::ListServicesResponse.new(
              service_arns: [ecs_service_arn_1, ecs_service_arn_2],
              next_token: ecs_list_services_response_1_next_token)
      ecs_list_services_response_2 =
          Aws::ECS::Types::ListServicesResponse.new(
              service_arns: [ecs_service_arn_3],
              next_token: nil)

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_clusters)
              .with(clusters: [ecs_cluster_name])
              .and_return(ecs_describe_clusters_response))
      allow(ecs_client)
          .to(receive(:list_services)
              .with(
                  cluster: ecs_cluster_name,
                  next_token: nil)
              .and_return(ecs_list_services_response_1))
      allow(ecs_client)
          .to(receive(:list_services)
              .with(
                  cluster: ecs_cluster_name,
                  next_token: ecs_list_services_response_1_next_token)
              .and_return(ecs_list_services_response_2))

      service_1 = double('service 1')
      service_2 = double('service 2')
      service_3 = double('service 3')

      allow(service_1)
          .to(receive(:is_replica?).and_return(true))
      allow(service_2)
          .to(receive(:is_replica?).and_return(false))
      allow(service_3)
          .to(receive(:is_replica?).and_return(true))

      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_1, region)
              .and_return(service_1))
      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_2, region)
              .and_return(service_2))
      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_3, region)
              .and_return(service_3))

      service_cluster = Rollo::Model::ServiceCluster.new(
          ecs_cluster_name, region, ecs_resource)

      expect(service_cluster.replica_services).to(eq([service_1, service_3]))
    end
  end

  context '#with_replica_services' do
    it 'uses the provided callback block to notify of all replica services' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_cluster = Aws::ECS::Types::Cluster.new(cluster_name: ecs_cluster_name)

      ecs_service_arn_1 = 'aws:1234:ecs-service/some-ecs-service-name-1'
      ecs_service_arn_2 = 'aws:1234:ecs-service/some-ecs-service-name-2'
      ecs_service_arn_3 = 'aws:1234:ecs-service/some-ecs-service-name-3'

      ecs_describe_clusters_response =
          Aws::ECS::Types::DescribeClustersResponse.new(clusters: [ecs_cluster])
      ecs_list_services_response_1_next_token = SecureRandom.uuid
      ecs_list_services_response_1 =
          Aws::ECS::Types::ListServicesResponse.new(
              service_arns: [ecs_service_arn_1, ecs_service_arn_2],
              next_token: ecs_list_services_response_1_next_token)
      ecs_list_services_response_2 =
          Aws::ECS::Types::ListServicesResponse.new(
              service_arns: [ecs_service_arn_3],
              next_token: nil)

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_clusters)
              .with(clusters: [ecs_cluster_name])
              .and_return(ecs_describe_clusters_response))
      allow(ecs_client)
          .to(receive(:list_services)
              .with(
                  cluster: ecs_cluster_name,
                  next_token: nil)
              .and_return(ecs_list_services_response_1))
      allow(ecs_client)
          .to(receive(:list_services)
              .with(
                  cluster: ecs_cluster_name,
                  next_token: ecs_list_services_response_1_next_token)
              .and_return(ecs_list_services_response_2))

      service_1 = double('service 1')
      service_2 = double('service 2')
      service_3 = double('service 3')

      allow(service_1)
          .to(receive(:is_replica?).and_return(true))
      allow(service_2)
          .to(receive(:is_replica?).and_return(false))
      allow(service_3)
          .to(receive(:is_replica?).and_return(true))

      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_1, region)
              .and_return(service_1))
      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_2, region)
              .and_return(service_2))
      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_3, region)
              .and_return(service_3))

      service_cluster = Rollo::Model::ServiceCluster.new(
          ecs_cluster_name, region, ecs_resource)

      found_services = []
      service_cluster.with_replica_services do |on|
        on.start do |services|
          found_services = services
        end
      end

      expect(found_services).to(eq([service_1, service_3]))
    end

    it 'uses the provided callback block to provide each replica service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'
      ecs_cluster = Aws::ECS::Types::Cluster.new(cluster_name: ecs_cluster_name)

      ecs_service_arn_1 = 'aws:1234:ecs-service/some-ecs-service-name-1'
      ecs_service_arn_2 = 'aws:1234:ecs-service/some-ecs-service-name-2'
      ecs_service_arn_3 = 'aws:1234:ecs-service/some-ecs-service-name-3'

      ecs_describe_clusters_response =
          Aws::ECS::Types::DescribeClustersResponse.new(clusters: [ecs_cluster])
      ecs_list_services_response_1_next_token = SecureRandom.uuid
      ecs_list_services_response_1 =
          Aws::ECS::Types::ListServicesResponse.new(
              service_arns: [ecs_service_arn_1, ecs_service_arn_2],
              next_token: ecs_list_services_response_1_next_token)
      ecs_list_services_response_2 =
          Aws::ECS::Types::ListServicesResponse.new(
              service_arns: [ecs_service_arn_3],
              next_token: nil)

      ecs_client = double('ecs client')
      ecs_resource = Struct.new(:client).new(ecs_client)
      allow(ecs_client)
          .to(receive(:describe_clusters)
              .with(clusters: [ecs_cluster_name])
              .and_return(ecs_describe_clusters_response))
      allow(ecs_client)
          .to(receive(:list_services)
              .with(
                  cluster: ecs_cluster_name,
                  next_token: nil)
              .and_return(ecs_list_services_response_1))
      allow(ecs_client)
          .to(receive(:list_services)
              .with(
                  cluster: ecs_cluster_name,
                  next_token: ecs_list_services_response_1_next_token)
              .and_return(ecs_list_services_response_2))

      service_1 = double('service 1')
      service_2 = double('service 2')
      service_3 = double('service 3')

      allow(service_1)
          .to(receive(:is_replica?).and_return(true))
      allow(service_2)
          .to(receive(:is_replica?).and_return(false))
      allow(service_3)
          .to(receive(:is_replica?).and_return(true))

      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_1, region)
              .and_return(service_1))
      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_2, region)
              .and_return(service_2))
      allow(Rollo::Model::Service)
          .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn_3, region)
              .and_return(service_3))

      service_cluster = Rollo::Model::ServiceCluster.new(
          ecs_cluster_name, region, ecs_resource)

      found_services = []
      service_cluster.with_replica_services do |on|
        on.each_service do |service|
          found_services << service
        end
      end

      expect(found_services).to(eq([service_1, service_3]))
    end
  end
end
