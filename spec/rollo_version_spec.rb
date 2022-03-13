# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'rollo version', type: :aruba do
  before { run_command('rollo version') }

  it { expect(last_command_started).to have_output(Rollo::VERSION) }
end
