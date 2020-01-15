require 'rails/generators/migration'

module HuginnRecordLinkAgent
  module Generators
    class InstallGenerator < ::Rails::Generators::Base

      def add_migrations
        run 'bundle exec rake railties:install:migrations FROM=huginn_record_link_agent_engine'
      end

      def run_migrations
        run 'bundle exec rake db:migrate'
      end

    end
  end
end
