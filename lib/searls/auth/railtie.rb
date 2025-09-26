module Searls
  module Auth
    class Railtie < ::Rails::Railtie
      # Register rake tasks if needed
      # rake_tasks do
      #   load "tasks/searls_auth_tasks.rake"
      # end

      # Register generators if needed
      # generators do
      #   require "generators/searls_auth_generator"
      # end

      # Initialize configuration defaults
      initializer "searls.auth.configure" do |app|
      end
    end
  end
end
