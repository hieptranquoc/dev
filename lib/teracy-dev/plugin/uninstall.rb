require_relative '../logging'
require_relative 'bundler'

module TeracyDev
  module Plugin
    class Uninstall

      def self.instance
        @instance ||= self.new
      end

      def initialize
        @logger = TeracyDev::Logging.logger_for(self.class.name)

        plugin_manager = Vagrant::Plugin::Manager.instance
        @installed_plugins = plugin_manager.installed_plugins

        @user_file = plugin_manager.user_file
        @system_file = plugin_manager.system_file
      end

      def uninstall_plugin(name)
        if @system_file
          if !@user_file.has_plugin?(name) && @system_file.has_plugin?(name)
            @logger.error("The plugin you're attempting to uninstall (#{name}) is a
            system plugin. This means that the plugin is part of the installation
            of Vagrant. These plugins cannot be removed.

            You can however, install a plugin with the same name to replace
            these plugins. User-installed plugins take priority over
            system-installed plugins.")
          end
        end

        if !@user_file.has_plugin?(name)
          @logger.error("The plugin #{name} is not currently installed.")
          return
        end

        @user_file.remove_plugin(name)

        # Clean the environment, removing any old plugins
        TeracyDev::Plugin::Bundler.instance.clean(@installed_plugins)
      end

    end
  end
end
