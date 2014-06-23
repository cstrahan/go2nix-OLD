require 'yajl'
require 'stringio'
require 'tmpdir'

module Go2nix
  module Go
    class RepoRoot
      GO_REPO_ROOT_PATH = "go-repo-root"

      attr_reader :vcs
      attr_reader :root
      attr_reader :repo

      def self.from_import(import)
        json = `#{GO_REPO_ROOT_PATH.shellescape} --import-path #{import.shellescape} 2>&1`
        if !$?.success?
          raise json
        end
        json = Yajl::Parser.parse(json)

        from_json(json)
      end

      def self.from_json(json)
        repo = new
        vcs = VCS.from_cmd(json["VCS"]["Cmd"])
        repo.send("instance_variable_set", "@vcs", vcs)
        repo.send("instance_variable_set", "@root", json["Root"])
        repo.send("instance_variable_set", "@repo", json["Repo"])

        repo
      end
    end

    class Package
      attr_reader :doc
      attr_reader :dir
      attr_reader :root
      attr_reader :import_path
      attr_reader :deps
      attr_reader :go_files
      attr_reader :cgo_files
      attr_reader :ignored_go_files
      attr_reader :test_go_files
      attr_reader :test_imports
      attr_reader :xtest_go_files
      attr_reader :xtest_imports
      attr_reader :error

      ATTR_MAPPINGS = %w{
        doc              Doc

        dir              Dir
        root             Root
        import_path      ImportPath
        deps             Deps
        is_standard      Standard

        go_files         GoFiles
        cgo_files        CgoFiles
        ignored_go_files IgnoredGoFiles

        test_go_files    TestGoFiles
        test_imports     TestImports
        xtest_go_files   XTestGoFiles
        xtest_imports    XTestImports
      }.each_slice(2).to_a

      def initialize
        @deps             = []
        @go_files         = []
        @cgo_files        = []
        @ignored_go_files = []
        @test_go_files    = []
        @test_imports     = []
        @xtest_go_files   = []
        @xtest_imports    = []
      end

      def self.date_of_revision(import, revision)
        Dir.mktmpdir do |dir|
          system "GOPATH=#{dir.shellescape} go get #{import.shellescape} 2>/dev/null"
          repo_root = RepoRoot.from_import(import)

          src = File.join(dir, "src", repo_root.root)
          repo_root.vcs.revision_date(src)
        end
      end

      def self.from_import(gopath, import)
        json = `GOPATH=#{gopath.shellescape} go list -e -json #{import.shellescape}`
        json = StringIO.new(json)

        all = []
        Yajl::Parser.parse(json) do |obj|
          #if !obj["Error"].nil?
          #  raise obj["Error"]["Err"]
          #end
          all << from_json(obj)
        end

        all
      end

      def self.from_json(json)
        pkg = new
        ATTR_MAPPINGS.each do |rb, go|
          pkg.send("instance_variable_set", "@#{rb}", json[go]) if json[go]
        end

        if json["Error"]
          pkg.send("instance_variable_set", "@error", json["Error"]["Err"])
        end

        pkg
      end

      def error?
        !!error
      end

      def self.standard?(import)
        #json = `go list -e -json #{import.shellescape}`
        #return false unless $?.success?

        #json = JSON.parse(json)
        #json["Standard"]
        return !(/^(github\.com|code\.google\.com|((bazaar|code)\.)?launchpad\.net)/ =~ import)
      end

      def self.all_imports(pkgs)
        all = []
        pkgs.each do |pkg|
          all.concat(pkg.deps)
          all.concat(pkg.test_imports)
          all.concat(pkg.xtest_imports)
        end
        all.uniq!
        all.sort!
      end

      def standard?
        @is_standard
      end
    end
  end
end
