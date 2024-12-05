class HotwireSpark::Installer
  attr_reader :file_watcher

  def initialize(application)
    @application = application
  end

  def install
    configure_middleware
    monitor_paths
  end

  private
    attr_reader :application
    delegate :middleware, to: :application

    def configure_middleware
      ::ActionCable::Server::Base.prepend(HotwireSpark::ActionCable::PersistentCableServer)

      # TODO: Temporary patch until this gets merged https://github.com/rails/solid_cable/pull/50
      if defined?(::ActionCable::SubscriptionAdapter::SolidCable::Listener)
        ActionCable::SubscriptionAdapter::SolidCable::Listener.prepend(HotwireSpark::ActionCable::SolidCableWithSafeReloads)
      end

      middleware.insert_before ActionDispatch::Executor, HotwireSpark::ActionCable::PersistentCableMiddleware
      middleware.use HotwireSpark::Middleware
    end

    def monitor_paths
      monitor :css_paths, action: :reload_css
      monitor :html_paths, action: :reload_html
      monitor :stimulus_paths, action: :reload_stimulus

      file_watcher.start
    end

    def monitor(paths_name, action:)
      file_watcher.monitor HotwireSpark.public_send(paths_name) do |file_path|
        ActionCable.server.broadcast "hotwire_spark", reload_message_for(action, file_path)
      end
    end

    def file_watcher
      @file_watches ||= HotwireSpark::FileWatcher.new
    end

    def reload_message_for(action, file_path)
      { action: action, path: file_path }
    end
end
