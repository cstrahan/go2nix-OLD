require 'shellwords'
require 'time'

module Go2nix
  module VCS
    def self.from_cmd(cmd)
      [ Git, Bazaar, Mercurial ].detect { |vcs| vcs.cmd == cmd }
    end

    module Git
      def self.cmd
        "git"
      end

      def self.find_revision(dir, til)
        time = til.strftime("%Y-%m-%d %T")
        Dir.chdir(dir) do
          `git log --until #{time.shellescape} --pretty=format:'%H' -n1`.chomp
        end
      end

      def self.current_rev(dir)
        Dir.chdir(dir) do
          `git rev-parse HEAD`.chomp
        end
      end

      def self.tag_sync(dir, tag)
        Dir.chdir(dir) do
          `git checkout #{tag.shellescape} >/dev/null 2>&1`
        end
      end
    end

    module Mercurial
      def self.cmd
        "hg"
      end

      def self.find_revision(dir, til)
        time = til.strftime("%Y-%m-%d %T")
        Dir.chdir(dir) do
          `hg log -r \"sort(date('<#{time.shellescape}'), -rev)\" --template '{rev}\n' --limit 1`.chomp
        end
      end

      def self.current_rev(dir)
        Dir.chdir(dir) do
          `hg identify --id --debug`.chomp
        end
      end

      def self.tag_sync(dir, tag)
        Dir.chdir(dir) do
          `hg update -r #{tag.shellescape} >/dev/null 2>&1`
        end
      end
    end

    module Bazaar
      DATE_FORMAT = "%a %Y-%m-%d %T %z"

      def self.cmd
        "bzr"
      end

      def self.find_revision(dir, til)
        rev = nil

        lines = Dir.chdir(dir) do
          `bzr log --log-format=long`.split("\n")
        end

        lines.each do |line|
          if line.start_with?("revno: ")
            rev = line.split(" ")[1]
          elsif line.start_with?("timestamp: ")
            date = line.split(" ", 2).last
            date = DateTime.strptime(date, DATE_FORMAT)
            break if date < til
          end
        end

        rev
      end

      def self.current_rev(dir)
        Dir.chdir(dir) do
          `bzr revno`.chomp
        end
      end

      def self.tag_sync(dir, tag)
        Dir.chdir(dir) do
          `bzr update -r #{tag.shellescape} >/dev/null 2>&1`
        end
      end
    end
  end
end
