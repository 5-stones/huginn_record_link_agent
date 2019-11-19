require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::RecordLinkAgent do
  before(:each) do
    @valid_options = Agents::RecordLinkAgent.new.default_options
    @checker = Agents::RecordLinkAgent.new(:name => "RecordLinkAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
