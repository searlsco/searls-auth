module Searls
  module Auth
    class Engine < ::Rails::Engine
      isolate_namespace Searls::Auth

      initializer "searls.auth.helpers" do
        ActiveSupport.on_load(:action_controller) do
          helper Searls::Auth::Engine.helpers
        end
      end

      initializer "searls.auth.url_options" do |app|
        Searls::Auth::Engine.routes.default_url_options = app.routes.default_url_options
      end

      initializer "searls.auth.assets" do |app|
        app.config.assets.paths << root.join("app/javascript")
      end

      initializer "searls.auth.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << root.join("app/javascript")
        end
      end
    end
  end
end
