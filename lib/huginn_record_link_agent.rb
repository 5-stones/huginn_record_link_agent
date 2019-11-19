require 'huginn_record_link_agent/engine'
require 'huginn_agent'

module HuginnRecordLinkAgent
  #HuginnAgent.load 'huginn_record_link_agent/concerns/my_agent_concern'
  HuginnAgent.register 'huginn_record_link_agent/record_link_agent'
end
