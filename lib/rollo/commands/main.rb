# frozen_string_literal: true

require 'thor'
require_relative '../model'
require_relative './hosts'
require_relative './services'

module Rollo
  module Commands
    class Main < Thor
      namespace :main

      def self.exit_on_failure?
        true
      end

      desc('hosts', 'Manages the host cluster')
      subcommand :hosts, Rollo::Commands::Hosts

      desc('services', 'Manages the service cluster')
      subcommand :services, Rollo::Commands::Services

      desc('version', 'Prints the version number of rollo')
      def version
        say Rollo::VERSION
      end

      desc('roll REGION ASG_NAME ECS_CLUSTER_NAME',
           'Rolls all hosts in the cluster')
      method_option(
        :batch_size,
        aliases: '-b',
        type: :numeric,
        default: 3,
        desc:
            'The number of hosts / service instances to add / remove at ' \
                'a time.'
      )
      method_option(
        :maximum_service_instances,
        aliases: '-mx',
        type: :numeric,
        desc: 'The maximum number of service instances to expand to.'
      )
      method_option(
        :minimum_service_instances,
        aliases: '-mn',
        type: :numeric,
        desc: 'The minimum number of service instances to contract to.'
      )
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      def roll(region, asg_name, ecs_cluster_name)
        host_cluster = Rollo::Model::HostCluster.new(asg_name, region)
        service_cluster = Rollo::Model::ServiceCluster
                          .new(ecs_cluster_name, region)

        initial_hosts = host_cluster.hosts

        say(
          "Rolling instances in host cluster #{host_cluster.name} for " \
              "service cluster #{service_cluster.name}..."
        )
        # rubocop:disable Metrics/BlockLength
        with_padding do
          unless host_cluster.desired_capacity?
            say('ERROR: Host cluster is not in stable state.')
            say('This may be due to scaling above or below the desired')
            say('capacity or because hosts are not in service or are ')
            say('unhealthy. Cowardly refusing to roll instances.')
            exit 1
          end

          invoke(
            'hosts:expand',
            [
              region, asg_name, ecs_cluster_name,
              host_cluster
            ]
          )

          invoke(
            'services:expand',
            [
              region, asg_name, ecs_cluster_name,
              service_cluster
            ],
            maximum_instances: options[:maximum_service_instances]
          )

          invoke(
            'hosts:terminate',
            [
              region, asg_name, ecs_cluster_name, initial_hosts.map(&:id),
              host_cluster, service_cluster
            ]
          )

          invoke(
            'hosts:contract',
            [
              region, asg_name, ecs_cluster_name,
              host_cluster, service_cluster
            ]
          )

          invoke(
            'services:contract',
            [
              region, asg_name, ecs_cluster_name,
              service_cluster
            ],
            minimum_instances: options[:minimum_service_instances]
          )
        end
        # rubocop:enable Metrics/BlockLength
        say("Instances in host cluster #{host_cluster.name} rolled " \
            'successfully.')
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/AbcSize
    end
  end
end
