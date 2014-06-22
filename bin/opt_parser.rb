require 'optparse'
require 'optparse/time'
require 'ostruct'

class OptParser
  def self.parse(args)
    options = OpenStruct.new
    parser(options).parse!(args)
    options
  end

  def self.parser(options)
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: go2nix [options]"

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("--pkg PACKAGE",
              "The package to fetch dependencies of") do |pkg|
        options.package = pkg
      end

      opts.on("--until DATE",
              "The latest revisions to fetch in iso8601 format (e.g. \"2014-05-03T00:00:00Z\")") do |date|
        if date == "auto"
          options.til = :auto
        else
          til = DateTime.iso8601(date) rescue nil
          if til.nil?
            puts "Invalid format for --until: #{date}"
            exit 1
          end
          options.til = til
        end
      end

      opts.on("--rev REVISION",
              "The revision to fetch") do |revision|
        options.revision = revision
      end

      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    opt_parser
  end
end
