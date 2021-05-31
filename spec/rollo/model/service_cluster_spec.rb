# frozen_string_literal: true

require 'securerandom'
require_relative '../../spec_helper'

# rubocop:disable RSpec/ExampleLength
# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe Rollo::Model::ServiceCluster do
  describe 'attributes' do
    it 'exposes the ECS cluster name' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_clusters,
        { clusters: [{ cluster_name: ecs_cluster_name }] }
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service_cluster = described_class.new(
        ecs_cluster_name, region, ecs_resource
      )

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :describe_clusters }
          .first[:params]).to(eq(clusters: [ecs_cluster_name]))
      expect(service_cluster.name).to(eq(ecs_cluster_name))
    end

    it 'exposes the replica services in the ECS cluster' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'

      ecs_service_arn1 = 'aws:1234:ecs-service/some-ecs-service-name-1'
      ecs_service_arn2 = 'aws:1234:ecs-service/some-ecs-service-name-2'
      ecs_service_arn3 = 'aws:1234:ecs-service/some-ecs-service-name-3'

      next_token = SecureRandom.uuid

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_clusters,
        { clusters: [{ cluster_name: ecs_cluster_name }] }
      )
      ecs_client.stub_responses(
        :list_services,
        [
          {
            service_arns: [ecs_service_arn1, ecs_service_arn2],
            next_token: next_token
          },
          {
            service_arns: [ecs_service_arn3],
            next_token: nil
          }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service1 = double('service 1')
      service2 = double('service 2')
      service3 = double('service 3')

      allow(service1).to(receive(:replica?).and_return(true))
      allow(service2).to(receive(:replica?).and_return(false))
      allow(service3).to(receive(:replica?).and_return(true))

      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn1, region)
              .and_return(service1))
      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn2, region)
              .and_return(service2))
      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn3, region)
              .and_return(service3))

      service_cluster = described_class.new(
        ecs_cluster_name, region, ecs_resource
      )

      replica_services = service_cluster.replica_services

      expect(ecs_client.api_requests
          .select { |r| r[:operation_name] == :list_services }
          .map { |r| r[:params] })
        .to(eq([
                 { cluster: ecs_cluster_name },
                 { cluster: ecs_cluster_name, next_token: next_token }
               ]))
      expect(replica_services).to(eq([service1, service3]))
    end
  end

  describe '#with_replica_services' do
    it 'uses the provided callback block to notify of all replica services' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'

      ecs_service_arn1 = 'aws:1234:ecs-service/some-ecs-service-name-1'
      ecs_service_arn2 = 'aws:1234:ecs-service/some-ecs-service-name-2'
      ecs_service_arn3 = 'aws:1234:ecs-service/some-ecs-service-name-3'

      next_token = SecureRandom.uuid

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_clusters,
        { clusters: [{ cluster_name: ecs_cluster_name }] }
      )
      ecs_client.stub_responses(
        :list_services,
        [
          {
            service_arns: [ecs_service_arn1, ecs_service_arn2],
            next_token: next_token
          },
          {
            service_arns: [ecs_service_arn3],
            next_token: nil
          }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service1 = double('service 1')
      service2 = double('service 2')
      service3 = double('service 3')

      allow(service1)
        .to(receive(:replica?).and_return(true))
      allow(service2)
        .to(receive(:replica?).and_return(false))
      allow(service3)
        .to(receive(:replica?).and_return(true))

      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn1, region)
              .and_return(service1))
      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn2, region)
              .and_return(service2))
      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn3, region)
              .and_return(service3))

      service_cluster = described_class.new(
        ecs_cluster_name, region, ecs_resource
      )

      found_services = []
      service_cluster.with_replica_services do |on|
        on.start do |services|
          found_services = services
        end
      end

      expect(found_services).to(eq([service1, service3]))
    end

    it 'uses the provided callback block to provide each replica service' do
      region = 'eu-west-1'
      ecs_cluster_name = 'some-ecs-cluster'

      ecs_service_arn1 = 'aws:1234:ecs-service/some-ecs-service-name-1'
      ecs_service_arn2 = 'aws:1234:ecs-service/some-ecs-service-name-2'
      ecs_service_arn3 = 'aws:1234:ecs-service/some-ecs-service-name-3'

      next_token = SecureRandom.uuid

      ecs_client = Aws::ECS::Client.new(stub_responses: true)
      ecs_client.stub_responses(
        :describe_clusters,
        { clusters: [{ cluster_name: ecs_cluster_name }] }
      )
      ecs_client.stub_responses(
        :list_services,
        [
          {
            service_arns: [ecs_service_arn1, ecs_service_arn2],
            next_token: next_token
          },
          {
            service_arns: [ecs_service_arn3],
            next_token: nil
          }
        ]
      )
      ecs_resource = Aws::ECS::Resource.new(client: ecs_client)

      service1 = double('service 1')
      service2 = double('service 2')
      service3 = double('service 3')

      allow(service1)
        .to(receive(:replica?).and_return(true))
      allow(service2)
        .to(receive(:replica?).and_return(false))
      allow(service3)
        .to(receive(:replica?).and_return(true))

      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn1, region)
              .and_return(service1))
      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn2, region)
              .and_return(service2))
      allow(Rollo::Model::Service)
        .to(receive(:new)
              .with(ecs_cluster_name, ecs_service_arn3, region)
              .and_return(service3))

      service_cluster = described_class.new(
        ecs_cluster_name, region, ecs_resource
      )

      found_services = []
      service_cluster.with_replica_services do |on|
        on.each_service do |service|
          found_services << service
        end
      end

      expect(found_services).to(eq([service1, service3]))
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
# rubocop:enable RSpec/ExampleLength
