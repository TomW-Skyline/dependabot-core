# typed: true
# frozen_string_literal: true

require "dependabot/shared_helpers"

module Dependabot
  module NpmAndYarn
    class PackageManager
      def initialize(package_json, lockfiles:)
        @package_json = package_json
        @lockfiles = lockfiles
      end

      def setup(name)
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
        version = @package_json.fetch("packageManager", nil)
        return unless version

        version_match = version.match(/#{name}@(?<version>\d+.\d+.\d+)/)
        version_match&.named_captures&.fetch("version", nil)
      end

      def guessed_version(name)
        send(:"guess_#{name}_version", @lockfiles[name.to_sym])
      end

      def guess_yarn_version(yarn_lock)
        return unless yarn_lock

        Helpers.yarn_version_numeric(yarn_lock)
      end

      def guess_pnpm_version(pnpm_lock)
        return unless pnpm_lock

        Helpers.pnpm_version_numeric(pnpm_lock)
      end
    end
  end
end
