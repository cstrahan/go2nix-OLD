module Go2nix
  class Revision
    attr_reader :root
    attr_reader :rev
    attr_reader :vcs
    attr_reader :deps

    def initialize(attrs)
      @root = attrs[:root]
      @repo = attrs[:repo]
      @doc  = attrs[:doc]
      @rev  = attrs[:rev]
      @vcs  = attrs[:vcs]
      @deps = attrs[:deps]
    end

    def as_json
      {
        :root => @root,
        :repo => @repo,
        :doc  => @doc,
        :rev  => @rev,
        :vcs  => @vcs,
        :deps => @deps
      }
    end
  end
end
