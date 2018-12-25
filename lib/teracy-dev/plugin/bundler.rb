require_relative '../logging'

require "set"
require "rubygems/uninstaller"

module TeracyDev
  module Plugin
    class Bundler < Vagrant::Bundler

      def self.instance
        @instance ||= self.new
      end

      def initialize
        @logger = TeracyDev::Logging.logger_for(self.class.name)
        @plugin_gem_path = Vagrant::Bundler.instance.plugin_gem_path
      end

      def clean(plugins)
        # Generate dependencies for all registered plugins
        plugin_deps = plugins.map do |name, info|
          gem_version = info['installed_gem_version']
          gem_version = info['gem_version'] if gem_version.to_s.empty?
          gem_version = "> 0" if gem_version.to_s.empty?
          Gem::Dependency.new(name, gem_version)
        end

        @logger.info("plugin_deps: #{plugin_deps}")

        # Load dependencies into a request set for resolution
        request_set = Gem::RequestSet.new(*plugin_deps)

        request_set.remote = false

        current_set = generate_vagrant_set # //?

        plugin_specs = Dir.glob(@plugin_gem_path.join('specifications/*.gemspec').to_s).map do |spec_path|
          Gem::Specification.load(spec_path)
        end

        solution = request_set.resolve(current_set)

        @logger.info("solution: #{solution}")

        solution_specs = solution.map(&:full_spec)

        @logger.info("solution_specs: #{solution_specs}")

        solution_full_names = solution_specs.map(&:full_name)

        @logger.info("solution_full_names: #{solution_full_names}")

        plugin_specs.delete_if do |spec|
          @logger.info("spec full name: #{spec.full_name}")
          solution_full_names.include?(spec.full_name)
        end

        @logger.info("plugin_specs after: #{plugin_specs}")

        @logger.info("Specifications to be removed - #{plugin_specs.map(&:full_name)}")

        # Now delete all unused specs
        @logger.info("plugin_specs before remove: #{plugin_specs}")

        plugin_specs.each do |spec|
          @logger.info("spec gem uninstaller: #{spec}")
          @logger.info("Uninstalling gem - #{spec.full_name}")
          Gem::Uninstaller.new(spec.name,
            version: spec.version,
            install_dir: plugin_gem_path,
            all: true,
            executables: true,
            force: true,
            ignore: true,
          ).uninstall_gem(spec)
        end

        @logger.info("solution: #{solution}")
        solution.find_all do |spec|
          plugins.keys.include?(spec.name)
        end
      end

      protected

      def generate_vagrant_set
        sets = generate_plugin_set(@plugin_gem_path)
        Gem::Resolver.compose_sets(*sets)
      end

      def generate_plugin_set(*args)
        plugin_path = args.detect{|i| i.is_a?(Pathname) } || @plugin_gem_path
        skip = args.detect{|i| i.is_a?(Array) } || []
        plugin_set = Vagrant::Bundler::PluginSet.new
        Dir.glob(plugin_path.join('specifications/*.gemspec').to_s).each do |spec_path|
          spec = Gem::Specification.load(spec_path)
          desired_spec_path = File.join(spec.gem_dir, "#{spec.name}.gemspec")
          # Vendor set requires the spec to be within the gem directory. Some gems will package their
          # spec file, and that's not what we want to load.
          if !File.exist?(desired_spec_path) || !FileUtils.cmp(spec.spec_file, desired_spec_path)
            File.write(desired_spec_path, spec.to_ruby)
          end
          next if skip.include?(spec.name) || skip.include?(spec.full_name)
          plugin_set.add_vendor_gem(spec.name, spec.gem_dir)
        end
        plugin_set
      end

    # END CLASS
    end
  end
end
