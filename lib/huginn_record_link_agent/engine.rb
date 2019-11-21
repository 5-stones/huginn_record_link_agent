module HuginnRecordLinkAgent
  class Engine < ::Rails::Engine
    config.autoload_paths += Dir["#{config.root}/app/models/**/"]
    config.autoload_paths += Dir["#{config.root}/app/utils/**/"]
  end
end
