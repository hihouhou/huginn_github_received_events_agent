require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::GithubReceivedEventsAgent do
  before(:each) do
    @valid_options = Agents::GithubReceivedEventsAgent.new.default_options
    @checker = Agents::GithubReceivedEventsAgent.new(:name => "GithubReceivedEventsAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
