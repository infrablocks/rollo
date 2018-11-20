require 'thor'
require_relative '../model'

module Rollo
  module Commands
    class Main < Thor
      def self.exit_on_failure?
        true
      end

      desc('version', 'prints the version number of rollo')
      def version
        puts Rollo::VERSION
      end

      desc('roll REGION ASG_NAME ECS_CLUSTER_NAME',
          'rolls all instances in an ECS cluster')
      def roll(region, asg_name, ecs_cluster_name)
        host_cluster = Rollo::HostCluster.new(asg_name, region)
        service_cluster = Rollo::ServiceCluster.new(ecs_cluster_name, region)

        puts(
            "Rolling instances in host cluster #{host_cluster.name} for " +
                "service cluster #{service_cluster.name}...")

        unless host_cluster.has_desired_capacity?
          puts('-> ERROR: Host cluster is not in stable state.')
          puts('   This may be due to scaling above or below the desired')
          puts('   capacity or because hosts are not in service or are ')
          puts('   unhealthy. Cowardly refusing to roll instances.')
          exit 1
        end

        batch_size = 3
        service_start_wait_minutes = 2
        service_start_wait_seconds = 60 * service_start_wait_minutes
        initial_hosts = host_cluster.hosts
        initial_host_batches = initial_hosts.each_slice(batch_size).to_a

        puts("-> Increasing host cluster desired capacity by #{batch_size}...")
        host_cluster.increase_capacity_by(batch_size) do |on|
          on.prepare do |current, target|
            puts("--> Changing desired capacity from #{current} to " +
                "#{target}...")
          end
          on.waiting_for_start do |attempt|
            puts(
                "--> Waiting for capacity change to start " +
                    "(attempt #{attempt})...")
          end
          on.waiting_for_complete do |attempt|
            puts(
                "--> Waiting for capacity change to complete " +
                    "(attempt #{attempt})...")
          end
          on.waiting_for_health do |attempt|
            puts("--> Waiting for a healthy state (attempt #{attempt})")
          end
        end
        puts "-> Host cluster desired capacity increased, continuing..."

        puts("-> Increasing service instance counts by #{batch_size}...")
        service_cluster.with_services do |on|
          on.start do |services|
            puts(
                "--> Service cluster contains services:" +
                    "\n\t\t[#{services.map(&:name).join(",\n\t\t ")}]")
          end
          on.each_service do |service|
            puts(
                "--> Increasing instance count by #{batch_size} " +
                    "for #{service.name}")
            service.increase_instance_count_by(batch_size) do |on|
              on.prepare do |current, target|
                puts(
                    "--> Changing instance count from #{current} " +
                        "to #{target}...")
              end
              on.waiting_for_health do |attempt|
                puts(
                    "--> Waiting for service to reach a steady state " +
                        "(attempt #{attempt})...")
              end
            end
          end
        end
        puts(
            "--> Waiting #{service_start_wait_minutes} minute(s) for " +
                "services to finish starting...")
        sleep(service_start_wait_seconds)
        puts(
            "--> Waited #{service_start_wait_minutes} minute(s). " +
                "Continuing...")
        puts("-> Service instance counts increased, continuing...")

        puts(
            "-> Terminating old hosts in host cluster in batches of " +
                "#{batch_size}...")
        initial_host_batches.each_with_index do |host_batch, index|
          puts(
              "--> Batch #{index + 1} contains hosts: " +
                  "\n\t\t[#{host_batch.map(&:id).join(",\n\t\t ")}]\n" +
                  "    Terminating...")
          host_batch.each {|h| h.terminate}
          host_cluster.wait_for_capacity_health do |on|
            on.waiting_for_health do |attempt|
              puts(
                  "--> Waiting for host cluster to reach healthy state " +
                      "(attempt #{attempt})")
            end
          end
          service_cluster.with_services do |on|
            on.each_service do |service|
              service.wait_for_service_health do |on|
                on.waiting_for_health do |attempt|
                  puts(
                      "--> Waiting for service #{service.name} to reach a " +
                          "steady state (attempt #{attempt})...")
                end
              end
            end
          end
          puts(
              "--> Waiting #{service_start_wait_minutes} minute(s) for " +
                  "services to finish starting...")
          sleep(service_start_wait_seconds)
          puts(
              "--> Waited #{service_start_wait_minutes} minute(s). " +
                  "Continuing...")
        end

        puts "-> Decreasing host cluster desired capacity by #{batch_size}..."
        host_cluster.decrease_capacity_by(batch_size) do |on|
          on.prepare do |current, target|
            puts("--> Changing desired capacity from #{current} to " +
                "#{target}...")
          end
          on.waiting_for_start do |attempt|
            puts(
                "--> Waiting for capacity change to start " +
                    "(attempt #{attempt})...")
          end
          on.waiting_for_complete do |attempt|
            puts(
                "--> Waiting for capacity change to complete " +
                    "(attempt #{attempt})...")
          end
          on.waiting_for_health do |attempt|
            puts(
                "--> Waiting for host cluster to reach healthy state " +
                    "(attempt #{attempt})...")
          end
        end
        service_cluster.with_services do |on|
          on.each_service do |service|
            service.wait_for_service_health do |on|
              on.waiting_for_health do |attempt|
                puts(
                    "--> Waiting for service #{service.name} to reach a " +
                        "steady state (attempt #{attempt})...")
              end
            end
          end
        end
        puts "-> Host cluster desired capacity decreased, continuing..."

        puts("-> Decreasing service instance counts by #{batch_size}...")
        service_cluster.with_services do |on|
          on.each_service do |service|
            puts(
                "--> Decreasing instance count by #{batch_size} " +
                    "for #{service.name}")
            service.decrease_instance_count_by(batch_size) do |on|
              on.prepare do |current, target|
                puts(
                    "---> Changing instance count from #{current} " +
                        "to #{target}...")
              end
              on.waiting_for_health do |attempt|
                puts(
                    "---> Waiting for service to reach a steady state " +
                        "(attempt #{attempt})...")
              end
            end
          end
        end
        puts("-> Service instance counts decreased, continuing...")

        puts("Instances in host cluster #{host_cluster.name} rolled " +
            "successfully.")
      end
    end
  end
end