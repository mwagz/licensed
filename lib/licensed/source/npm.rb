# frozen_string_literal: true
require "json"

module Licensed
  module Source
    class NPM
      def self.type
        "npm"
      end

      def initialize(config)
        @config = config
      end

      def enabled?
        Licensed::Shell.tool_available?("npm") && File.exist?(@config.pwd.join("package.json"))
      end

      def dependencies
        @dependencies ||= packages.map do |name, package|
          path = package["path"]

          if path.empty?
            next if @config.ignored?("type" => NPM.type, "name" => name)
            fail "couldn't locate #{name} under node_modules/"
          end

          Dependency.new(path, {
            "type"     => NPM.type,
            "name"     => package["name"],
            "version"  => package["version"],
            "summary"  => package["description"],
            "homepage" => package["homepage"],
            "path"     => name
          })
        end
      end

      def packages
        root_dependencies = JSON.parse(package_metadata_command)["dependencies"]
        recursive_dependencies(root_dependencies).each_with_object({}) do |(name, results), hsh|
          results.uniq! { |package| package["version"] }
          if results.size == 1
            hsh[name] = results[0]
          else
            results.each do |package|
              name_with_version = "#{name}-#{package["version"]}"
              hsh[name_with_version] = package
            end
          end
        end
      end

      # Recursively parse dependency JSON data.  Returns a hash mapping the
      # package name to it's metadata
      def recursive_dependencies(dependencies, result = {})
        dependencies.each do |name, dependency|
          (result[name] ||= []) << dependency
          recursive_dependencies(dependency["dependencies"] || {}, result)
        end
        result
      end

      # Returns the output from running `npm list` to get package metadata
      def package_metadata_command
        npm_list_command("--json", "--production", "--long")
      end

      # Executes an `npm list` command with the provided args and returns the
      # output from stdout
      def npm_list_command(*args)
        Licensed::Shell.execute("npm", "list", *args)
      end
    end
  end
end
