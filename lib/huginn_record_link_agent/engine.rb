module HuginnRecordLinkAgent
  class Engine < ::Rails::Engine

    # Install and run gem's migrations
    # run 'bundle exec rake railties:install:migrations FROM=huginn_record_link_agent_engine'
    # run 'bundle exec rake db:migrate'
    ## NOTE: This is designed for compatibility with ECS containers in AWS. These rake tasks fail to run in the standard
    #        huginn/huginn image fails to run the rake tasks if a docker container has no .env file (as appears to be the
    #        case when setting environment variables directly on the container definition in AWS)
    #
    #        Calling these tasks here circumvents that requirement (and maintains the convention of automatically
    #        setting up gems from the ADDITIONAL_GEMS environment variable)


    config.autoload_paths += Dir["../../app/models/**/"]
    config.autoload_paths += Dir["../../app/utils/**/"]
  end
end
