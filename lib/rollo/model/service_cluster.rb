require 'aws-sdk'
require 'hollerback'

require_relative './service'

module Rollo
  module Model
    class ServiceCluster
      def initialize(ecs_cluster_name, region, ecs_resource = nil)
        @region = region
        @ecs_cluster_name = ecs_cluster_name
        @ecs_resource = ecs_resource || Aws::ECS::Resource.new(region: region)
        @ecs_cluster = get_ecs_cluster
      end

      def name
        @ecs_cluster_name
      end

      def replica_services
        get_ecs_service_arns
            .collect {|arn| Service.new(@ecs_cluster_name, arn, @region)}
            .select {|service| service.is_replica?}
      end

      def with_replica_services(&block)
        all_replica_services = replica_services

        callbacks = Hollerback::Callbacks.new(block)
        callbacks.try_respond_with(
            :start, all_replica_services)

        all_replica_services.each do |service|
          callbacks.try_respond_with(:each_service, service)
        end
      end

      private

      def get_ecs_cluster
        @ecs_resource.client
            .describe_clusters(clusters: [@ecs_cluster_name])
            .clusters[0]
      end

      def get_ecs_service_arns
        @ecs_resource.client
            .list_services(cluster: @ecs_cluster.cluster_name)
            .inject([]) {|arns, response| arns + response.service_arns}
      end
    end
  end
end