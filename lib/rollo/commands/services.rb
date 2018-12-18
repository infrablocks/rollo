require 'thor'
require_relative '../model'

module Rollo
  module Commands
    class Services < Thor
      namespace :services

      def self.exit_on_failure?
        true
      end

      desc(
          'expand REGION ASG_NAME ECS_CLUSTER_NAME',
          'Expands the service cluster by one batch.')
      method_option(
          :batch_size,
          aliases: '-b',
          type: :numeric,
          default: 3,
          desc: 'The number of service instances to add at a time.')
      method_option(
          :startup_time,
          aliases: '-t',
          type: :numeric,
          default: 2,
          desc: 'The number of minutes to wait for services to start up.')
      method_option(
          :maximum_instances,
          aliases: '-mx',
          type: :numeric,
          desc: 'The maximum number of service instances to expand to.')

      def expand(
          region, _, ecs_cluster_name,
              service_cluster = nil)
        batch_size = options[:batch_size]
        maximum_instances = options[:maximum_instances]
        service_start_wait_minutes = options[:startup_time]
        service_start_wait_seconds = 60 * service_start_wait_minutes

        service_cluster = service_cluster ||
            Rollo::Model::ServiceCluster.new(ecs_cluster_name, region)

        say("Increasing service instance counts by #{batch_size}...")
        with_padding do
          service_cluster.with_replica_services do |on|
            on.start do |services|
              say(
                  'Service cluster contains services:' +
                      "\n\t\t[#{services.map(&:name).join(",\n\t\t ")}]")
            end
            on.each_service do |service|
              say(
                  "Increasing instance count by #{batch_size} " +
                      "for #{service.name}")
              with_padding do
                service.increase_instance_count_by(
                    batch_size, maximum_instances: maximum_instances) do |on|
                  on.prepare do |current, target|
                    say(
                        "Changing instance count from #{current} " +
                            "to #{target}...")
                  end
                  on.waiting_for_health do |attempt|
                    say(
                        "Waiting for service to reach a steady state " +
                            "(attempt #{attempt})...")
                  end
                end
              end
            end
          end
        end
        say(
            "Waiting #{service_start_wait_minutes} minute(s) for " +
                'services to finish starting...')
        with_padding do
          sleep(service_start_wait_seconds)
          say(
              "Waited #{service_start_wait_minutes} minute(s). " +
                  'Continuing...')
        end
        say('Service instance counts increased, continuing...')
      end

      desc(
          'contract REGION ASG_NAME ECS_CLUSTER_NAME',
          'Contracts the service cluster by one batch.')
      method_option(
          :batch_size,
          aliases: '-b',
          type: :numeric,
          default: 3,
          desc: 'The number of service instances to remove at a time.')
      method_option(
          :minimum_instances,
          aliases: '-mn',
          type: :numeric,
          desc: 'The minimum number of service instances to contract to.')

      def contract(
          region, _, ecs_cluster_name,
              service_cluster = nil)
        batch_size = options[:batch_size]

        service_cluster = service_cluster ||
            Rollo::Model::ServiceCluster.new(ecs_cluster_name, region)

        say("Decreasing service instance counts by #{batch_size}...")
        with_padding do
          service_cluster.with_replica_services do |on|
            on.each_service do |service|
              say(
                  "Decreasing instance count by #{batch_size} " +
                      "for #{service.name}")
              with_padding do
                service.decrease_instance_count_by(batch_size) do |on|
                  on.prepare do |current, target|
                    say(
                        "Changing instance count from #{current} " +
                            "to #{target}...")
                  end
                  on.waiting_for_health do |attempt|
                    say(
                        'Waiting for service to reach a steady state ' +
                            "(attempt #{attempt})...")
                  end
                end
              end
            end
          end
        end
        say("Service instance counts decreased, continuing...")
      end
    end
  end
end
