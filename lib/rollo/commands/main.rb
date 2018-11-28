require 'thor'
require_relative '../model'
require_relative './host_cluster'
require_relative './service_cluster'

module Rollo
  module Commands
    class Main < Thor
      def self.exit_on_failure?
        true
      end

      desc('host-cluster', 'manages the host cluster')
      subcommand "host-cluster", HostCluster

      desc('service-cluster', 'manages the service cluster')
      subcommand "service-cluster", ServiceCluster

      desc('version', 'prints the version number of rollo')
      def version
        say Rollo::VERSION
      end

      desc('roll REGION ASG_NAME ECS_CLUSTER_NAME',
          'rolls all instances in an ECS cluster')
      method_option(
          :batch_size,
          aliases: '-b',
          type: :numeric,
          default: 3,
          desc:
              'The number of hosts / service instances to add / remove at ' +
                  'a time.')
      def roll(region, asg_name, ecs_cluster_name)
        host_cluster = Rollo::HostCluster.new(asg_name, region)
        service_cluster = Rollo::ServiceCluster.new(ecs_cluster_name, region)

        initial_hosts = host_cluster.hosts

        say(
            "Rolling instances in host cluster #{host_cluster.name} for " +
                "service cluster #{service_cluster.name}...")
        with_padding do
          unless host_cluster.has_desired_capacity?
            say('ERROR: Host cluster is not in stable state.')
            say('This may be due to scaling above or below the desired')
            say('capacity or because hosts are not in service or are ')
            say('unhealthy. Cowardly refusing to roll instances.')
            exit 1
          end

          invoke(
              "host-cluster:expand",
              [
                  region, asg_name, ecs_cluster_name,
                  host_cluster
              ])

          invoke(
              "service-cluster:expand",
              [
                  region, asg_name, ecs_cluster_name,
                  service_cluster
              ])

          invoke(
              "host-cluster:terminate",
              [
                  region, asg_name, ecs_cluster_name, initial_hosts.map(&:id),
                  host_cluster, service_cluster
              ])

          invoke(
              "host-cluster:contract",
              [
                  region, asg_name, ecs_cluster_name,
                  host_cluster, service_cluster
              ])

          invoke(
              "service-cluster:contract",
              [
                  region, asg_name, ecs_cluster_name,
                  service_cluster
              ])
        end

        say("Instances in host cluster #{host_cluster.name} rolled " +
            "successfully.")
      end
    end
  end
end