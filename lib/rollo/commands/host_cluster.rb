require 'thor'
require_relative '../model'

module Rollo
  module Commands
    class HostCluster < Thor
      def self.exit_on_failure?
        true
      end

      desc(
          'expand REGION ASG_NAME ECS_CLUSTER_NAME',
          '')
      method_option(
          :batch_size,
          aliases: '-b',
          type: :numeric,
          default: 3,
          desc: 'The number of hosts to add at a time.')
      def expand(
          region, asg_name, _,
              host_cluster = nil)
        batch_size = options[:batch_size]

        host_cluster = host_cluster ||
            Rollo::Model::HostCluster.new(asg_name, region)

        say("Increasing host cluster desired capacity by #{batch_size}...")
        with_padding do
          host_cluster.increase_capacity_by(batch_size) do |on|
            on.prepare do |current, target|
              say(
                  "Changing desired capacity from #{current} to " +
                      "#{target}...")
            end
            on.waiting_for_start do |attempt|
              say(
                  'Waiting for capacity change to start ' +
                      "(attempt #{attempt})...")
            end
            on.waiting_for_end do |attempt|
              say(
                  'Waiting for capacity change to complete ' +
                      "(attempt #{attempt})...")
            end
            on.waiting_for_health do |attempt|
              say("Waiting for a healthy state (attempt #{attempt})")
            end
          end
        end
        say "Host cluster desired capacity increased, continuing..."
      end

      desc(
          'contract REGION ASG_NAME ECS_CLUSTER_NAME',
          '')
      method_option(
          :batch_size,
          aliases: '-b',
          type: :numeric,
          default: 3,
          desc: 'The number of hosts to remove at a time.')
      def contract(
          region, asg_name, ecs_cluster_name,
              host_cluster = nil, service_cluster = nil)
        batch_size = options[:batch_size]

        host_cluster = host_cluster ||
            Rollo::Model::HostCluster.new(asg_name, region)
        service_cluster = service_cluster ||
            Rollo::Model::ServiceCluster.new(ecs_cluster_name, region)

        say("Decreasing host cluster desired capacity by #{batch_size}...")
        with_padding do
          host_cluster.decrease_capacity_by(batch_size) do |on|
            on.prepare do |current, target|
              say(
                  "Changing desired capacity from #{current} to " +
                      "#{target}...")
            end
            on.waiting_for_start do |attempt|
              say(
                  "Waiting for capacity change to start " +
                      "(attempt #{attempt})...")
            end
            on.waiting_for_end do |attempt|
              say(
                  "Waiting for capacity change to complete " +
                      "(attempt #{attempt})...")
            end
            on.waiting_for_health do |attempt|
              say(
                  "Waiting for host cluster to reach healthy state " +
                      "(attempt #{attempt})...")
            end
          end
          service_cluster.with_replica_services do |on|
            on.each_service do |service|
              service.wait_for_service_health do |on|
                on.waiting_for_health do |attempt|
                  say(
                      "Waiting for service #{service.name} to reach a " +
                          "steady state (attempt #{attempt})...")
                end
              end
            end
          end
        end
        say "Host cluster desired capacity decreased, continuing..."
      end

      desc(
          'terminate REGION ASG_NAME ECS_CLUSTER_NAME INSTANCE_IDS*',
          '')
      method_option(
          :batch_size,
          aliases: '-b',
          type: :numeric,
          default: 3,
          desc: 'The number of hosts to add at a time.')
      method_option(
          :startup_time,
          aliases: '-t',
          type: :numeric,
          default: 2,
          desc: 'The number of minutes to wait for services to start up.')
      def terminate(
          region, asg_name, ecs_cluster_name, instance_ids,
              host_cluster = nil, service_cluster = nil)
        batch_size = options[:batch_size]

        service_start_wait_minutes = options[:startup_time]
        service_start_wait_seconds = 60 * service_start_wait_minutes

        host_cluster = host_cluster ||
            Rollo::Model::HostCluster.new(asg_name, region)
        service_cluster = service_cluster ||
            Rollo::Model::ServiceCluster.new(ecs_cluster_name, region)

        hosts = host_cluster.hosts.select {|h| instance_ids.include?(h.id) }
        host_batches = hosts.each_slice(batch_size).to_a

        say(
            'Terminating old hosts in host cluster in batches of ' +
                "#{batch_size}...")
        with_padding do
          host_batches.each_with_index do |host_batch, index|
            say(
                "Batch #{index + 1} contains hosts: " +
                    "\n\t\t[#{host_batch.map(&:id).join(",\n\t\t ")}]\n" +
                    'Terminating...')
            host_batch.each(&:terminate)
            host_cluster.wait_for_capacity_health do |on|
              on.waiting_for_health do |attempt|
                say(
                    'Waiting for host cluster to reach healthy state ' +
                        "(attempt #{attempt})")
              end
            end
            service_cluster.with_replica_services do |on|
              on.each_service do |service|
                service.wait_for_service_health do |on|
                  on.waiting_for_health do |attempt|
                    say(
                        "Waiting for service #{service.name} to reach a " +
                            "steady state (attempt #{attempt})...")
                  end
                end
              end
            end
            say(
                "Waiting #{service_start_wait_minutes} minute(s) for " +
                    'services to finish starting...')
            sleep(service_start_wait_seconds)
            say(
                "Waited #{service_start_wait_minutes} minute(s). " +
                    'Continuing...')
          end
        end

      end
    end
  end
end
