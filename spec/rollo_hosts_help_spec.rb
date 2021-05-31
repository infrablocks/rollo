# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'rollo version', type: :aruba do
  before { run('rollo hosts help') }

  it {
    expect(last_command_started)
      .to(have_output(
            including(
              'hosts help',
              'hosts expand',
              'hosts contract',
              'hosts terminate'
            )
          ))
  }
end
