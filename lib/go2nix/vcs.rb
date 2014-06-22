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

      def self.revision_date(dir, target_rev = current_rev(dir))
        Dir.chdir(dir) do
          date = `git log #{target_rev.shellescape} -n1 --format="%ad" --date=iso`.chomp
          DateTime.strptime(date, "%Y-%m-%d %T")
        end
      end
    end

    module Mercurial
      def self.cmd
        "hg"
      end

      def self.find_revision(dir, til)
        time = til.strftime("%Y-%m-%d %T")
        range = "sort(date('<#{time}'), -rev)"
        Dir.chdir(dir) do
          `hg log -r #{range.shellescape} --template '{rev}\n' --limit 1`.chomp
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

      def self.revision_date(dir, target_rev = current_rev(dir))
        Dir.chdir(dir) do
          date = `hg log -r #{target_rev.shellescape} --template '{date|isodatesec}\n' --limit 1`.chomp
          DateTime.strptime(date, "%Y-%m-%d %T")
        end
      end
    end

    module Bazaar
      DATE_FORMAT = "%a %Y-%m-%d %T %z"

      def self.cmd
        "bzr"
      end

      def self.find_revision(dir, til)
        log = revision_log(dir)
        log.each do |rev, date|
          return rev if date <= til
        end

        nil
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

      def self.revision_date(dir, target_rev = current_rev(dir))
        Dir.chdir(dir) do
          log = revision_log(dir)
          rev_date = log.detect { |rev, date| rev == target_rev }
          rev_date[1]
        end
      end

      private

      def self.revision_log(dir)
        Dir.chdir(dir) do
          rev_date = nil
          log = []

          lines = Dir.chdir(dir) do
            `bzr log --log-format=long`.split("\n")
          end

          lines.each do |line|
            if line.start_with?("revno: ")
              rev_date = [ line.split(" ")[1], nil ]
            elsif line.start_with?("timestamp: ")
              date = line.split(" ", 2).last
              date = DateTime.strptime(date, DATE_FORMAT)
              rev_date[1] = date
              log << rev_date
            end
          end

          log
        end
      end

    end
  end
end
