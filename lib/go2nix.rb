require 'go2nix/nix'
require 'go2nix/go'
require 'go2nix/opt_parser'
require 'go2nix/revision'
require 'go2nix/vcs'

require 'erubis'
require 'set'

module Go2nix
  TEMPLATE_PATH = File.expand_path("../nix.erb", __FILE__)

  def self.snapshot(gopath, tags, til, imports, revs=[], processed_imports=Set.new)
    imports.each do |import|
      next if Go::Package.standard?(import)

      repo_root = Go::RepoRoot.from_import(import)
      next if repo_root.nil?

      vcs = repo_root.vcs
      root = repo_root.root
      repo = repo_root.repo
      src = File.join(gopath, "src", root)

      if processed_imports.include?(import)
        next
      else
        processed_imports << import
      end

      puts root

      system("GOPATH=#{gopath.shellescape} go get #{import.shellescape} 2>/dev/null")

      rev = nil
      if til.nil?
        rev = vcs.current_rev(src)
      else
        rev = vcs.find_revision(src, til)
        vcs.tag_sync(src, rev)
      end
      date = vcs.revision_date(src, rev)

      puts "   rev:  #{rev}"
      puts "  date:  #{date}"
      puts ""

      doc = Go::Package.from_import(gopath, root, tags).first.doc
      pkgs = Go::Package.from_import(gopath, "#{root}...", tags)
      new_imports = Go::Package.all_imports(pkgs)
      deps = deps_from_imports(new_imports)
      deps.delete(root)

      revs << Revision.new(
        :root => root,
        :repo => repo,
        :doc  => doc,
        :rev  => rev,
        :vcs  => vcs.cmd,
        :deps => deps
      )

      snapshot(gopath, tags, til, deps, revs, processed_imports)
    end

    revs
  end

  def self.deps_from_imports(imports)
    deps = []
    imports.each do |import|
      next if Go::Package.standard?(import)
      repo_root = Go::RepoRoot.from_import(import)
      next if repo_root.nil?
      deps << repo_root.root
    end

    deps.uniq!
    deps.sort!
  end

  def self.render_nix(revisions)
    NixRenderer.render(revisions)
  end

  class NixRenderer
    attr_reader :revisions

    def self.render(revisions)
      new(revisions).render
    end

    def initialize(revisions)
      @revisions = revisions
    end

    def render
      template = File.open(TEMPLATE_PATH, &:read)
      renderer = Erubis::Eruby.new(template)
      renderer.result(binding)
    end

    private

    def usesGit?
      revisions.any? {|rev| rev.vcs == "git" && !rev.root.start_with?("github.com") }
    end

    def fetchers
      fetchers = []
      if revisions.any? {|rev| rev.root.start_with?("github.com") }
        fetchers << "fetchFromGitHub"
      end
      if revisions.any? {|rev| rev.vcs == "git" && !rev.root.start_with?("github.com") }
        fetchers << "fetchgit"
      end
      if revisions.any? {|rev| rev.vcs == "hg" }
        fetchers << "fetchhg"
      end
      if revisions.any? {|rev| rev.vcs == "bzr" }
        fetchers << "fetchbzr"
      end

      fetchers
    end

    def sha256(rev)
      if rev.root.start_with?("github.com")
        Nix.prefetch_github(owner(rev), repo(rev), rev.rev)
      elsif rev.vcs == "git"
        Nix.prefetch_git(rev.repo, rev.rev)
      elsif rev.vcs == "hg"
        Nix.prefetch_hg(rev.repo, rev.rev)
      elsif rev.vcs == "bzr"
        Nix.prefetch_bzr(rev.repo, rev.rev)
      end
    end

    def owner(rev)
      rev.root.split("/")[1]
    end

    def repo(rev)
      rev.root.split("/")[2]
    end
  end
end
