require_relative 'logging'
require_relative 'util'
require_relative 'plugin/uninstall'

module TeracyDev
  module Plugin
    # install or uninstall plugins bases on the plugins config
    def self.sync(plugins)
      @logger = TeracyDev::Logging.logger_for(self)

      plugins ||= []

      return if plugins.empty?

      install_list = plugins.select { |item| item['state'] == 'installed' }

      uninstall_list = plugins.select { |item| item['state'] == 'uninstalled' }

      # reload_required when any plugin is installed/uninstalled
      @reload_required = false

      install_plugin(install_list) unless install_list.empty?

      uninstall_plugin(uninstall_list) unless uninstall_list.empty?

      if @reload_required
        @logger.info("reloading...")
        exec "vagrant #{ARGV.join(" ")}"
      end
    end

    def self.installed?(plugin_name)
      return Vagrant.has_plugin?(plugin_name)
    end

    private

    def self.install_plugin(plugins)
      installed_plugin = Vagrant::Plugin::Manager.instance.installed_plugins

      default_sources = [
        "https://rubygems.org/",
        "https://gems.hashicorp.com/"
      ]

      plugins.each do |plugin|
        name = plugin['name']

        unless TeracyDev::Util.exist? name
          logger.warn("Plugin name must be configured for #{plugin}")
          next
        end

        opts = plugin.dup

        ["_id", "name", "state", "config_key", "options", "enabled"].each do |key|
          opts.delete(key)
        end

        if installed_plugin.empty? && !TeracyDev::Util.exist?(opts['sources'])
          opts['sources'] = default_sources
        end

        unless installed_plugin.has_key? name
          @logger.info("installing plugin: `#{name}` with options: #{opts}")

          Vagrant::Plugin::Manager.instance.install_plugin(name, TeracyDev::Util.symbolize(opts))

          @reload_required = true
        end
      end
    end

    def self.uninstall_plugin(plugins)
      installed_plugin = Vagrant::Plugin::Manager.instance.installed_plugins

      plugins.each do |plugin|
        name = plugin['name']

        unless TeracyDev::Util.exist? name
          @logger.warn("Plugin name must be configured for #{plugin}")
          next
        end

        opts = plugin.dup

        opts.each do |key, value|
          if key != 'env_local'
            opts.delete(key)
          end
        end

        if installed_plugin.has_key? name
          @logger.info("uninstalling plugin: `#{name}` with options: #{opts}")

          if TeracyDev::Util.true?(opts['env_local'])
            Vagrant::Plugin::Manager.instance.uninstall_plugin(name, TeracyDev::Util.symbolize(opts))
          else
            TeracyDev::Plugin::Uninstall.instance.uninstall_plugin(name)
          end

          # @reload_required = true
        end
      end
    end

  end
end
