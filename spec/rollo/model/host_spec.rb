# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Rollo::Model::Host do
  it 'exposes the underlying instance ID' do
    region = 'eu-west-2'
    group_name = 'some-auto-scaling-group'
    instance_id = 'i-002b8e107dc646e5b'
    instance = Aws::AutoScaling::Instance.new(
      group_name, instance_id, region:
    )

    host = described_class.new(instance)

    expect(host.id).to(eq(instance_id))
  end

  it 'terminates the underlying instance' do
    region = 'eu-west-2'
    group_name = 'some-auto-scaling-group'
    instance_id = 'i-002b8e107dc646e5b'
    instance = Aws::AutoScaling::Instance.new(
      group_name, instance_id, region:
    )
    allow(instance).to(receive(:terminate))

    host = described_class.new(instance)
    host.terminate

    expect(instance)
      .to(have_received(:terminate)
            .with(should_decrement_desired_capacity: false))
  end

  it 'is in service when the lifecycle state is InService' do
    region = 'eu-west-2'
    group_name = 'some-auto-scaling-group'
    instance_id = 'i-002b8e107dc646e5b'
    instance = Aws::AutoScaling::Instance.new(
      group_name, instance_id,
      region:, data: { lifecycle_state: 'InService' }
    )

    host = described_class.new(instance)

    expect(host.in_service?).to(be(true))
  end

  it 'is not in service when the lifecycle state is Terminated' do
    region = 'eu-west-2'
    group_name = 'some-auto-scaling-group'
    instance_id = 'i-002b8e107dc646e5b'
    instance = Aws::AutoScaling::Instance.new(
      group_name, instance_id,
      region:, data: { lifecycle_state: 'Terminated' }
    )

    host = described_class.new(instance)

    expect(host.in_service?).to(be(false))
  end

  it 'is healthy when the underlying instance has health status of Healthy' do
    region = 'eu-west-2'
    group_name = 'some-auto-scaling-group'
    instance_id = 'i-002b8e107dc646e5b'
    instance = Aws::AutoScaling::Instance.new(
      group_name, instance_id,
      region:, data: { health_status: 'Healthy' }
    )

    host = described_class.new(instance)

    expect(host.healthy?).to(be(true))
  end

  it 'is unhealthy when the underlying instance has health status of ' \
     'Unhealthy' do
    region = 'eu-west-2'
    group_name = 'some-auto-scaling-group'
    instance_id = 'i-002b8e107dc646e5b'
    instance = Aws::AutoScaling::Instance.new(
      group_name, instance_id,
      region:, data: { health_status: 'Unhealthy' }
    )

    host = described_class.new(instance)

    expect(host.healthy?).to(be(false))
  end
end
