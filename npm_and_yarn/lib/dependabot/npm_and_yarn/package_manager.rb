# typed: true
# frozen_string_literal: true

require "dependabot/shared_helpers"

module Dependabot
  module NpmAndYarn
    class PackageManager
      def initialize(package_json, lockfiles:)
        @package_json = package_json
        @lockfiles = lockfiles
        @package_manager = package_json.fetch("packageManager", nil)
      end

      def setup(name)
        return unless @package_manager.nil? || @package_manager.start_with?("#{name}@")

        version = requested_version(name)

        if version
          install(name, version)
        else
          version = guessed_version(name)

          if version && name == "pnpm"
            if Version.new(version.to_s) < Version.new("7")
              raise ToolVersionNotSupported.new("PNPM", version.to_s, "7.*, 8.*")
            end

            install(name, version)
          end
        end

        version
      end

      private

      def install(name, version)
        SharedHelpers.run_shell_command(
          "corepack install #{name}@#{version} --global --cache-only",
          fingerprint: "corepack install <name>@<version> --global --cache-only"
        )
      end

      def requested_version(name)
        return unless @package_manager

        @package_manager.match(/#{name}@(?<version>\d+.\d+.\d+)/)["version"]
      end

      def guessed_version(name)
        lockfile = @lockfiles[name.to_sym]
        return unless lockfile

        Helpers.send(:"#{name}_version_numeric", lockfile)
      end
    end
  end
end
