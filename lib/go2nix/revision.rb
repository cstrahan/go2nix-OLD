module Go2nix
  class Revision
    attr_reader :root
    attr_reader :rev
    attr_reader :vcs
    attr_reader :deps

    def initialize(attrs)
      @root = attrs[:root]
      @rev  = attrs[:rev]
      @vcs  = attrs[:vcs]
      @deps = attrs[:deps]
    end

    def as_json
      {
        :root => @root,
        :rev  => @rev,
        :vcs  => @vcs,
        :deps => @deps
      }
    end
  end
end
