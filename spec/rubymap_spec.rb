# frozen_string_literal: true

RSpec.describe Rubymap do
  it "has a version number" do
    expect(Rubymap::VERSION).not_to be nil
  end

  it "defines an Error class" do
    expect(Rubymap::Error).to be < StandardError
  end
end
