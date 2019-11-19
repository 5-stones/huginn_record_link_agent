module HuginnRecordLinkAgent
  class Engine < ::Rails::Engine
    config.autoload_paths += Dir["#{config.root}/app/models/**/"]
  end
end
