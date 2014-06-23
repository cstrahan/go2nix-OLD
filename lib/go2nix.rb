require 'go2nix/go'
require 'go2nix/revision'
require 'go2nix/vcs'
require 'erubis'
require 'go2nix/nix'

module Go2nix
  TEMPLATE_PATH = File.expand_path("../nix.erb", __FILE__)

  def self.snapshot(gopath, til, imports, revs=[])
    imports.each do |import|
      next if Go::Package.standard?(import)

      repo_root = Go::RepoRoot.from_import(import) rescue nil
      vcs = repo_root.vcs
      root = repo_root.root
      repo = repo_root.repo
      src = File.join(gopath, "src", root)

      next if File.directory?(src)

      puts root
      system("GOPATH=#{gopath.shellescape} go get #{import.shellescape} 2>/dev/null")

      if til.nil?
        rev = vcs.current_rev(src)
      else
        rev = vcs.find_revision(src, til)
        vcs.tag_sync(src, rev)
      end

      doc = Go::Package.from_import(gopath, root).first.doc
      pkgs = Go::Package.from_import(gopath, "#{root}...")
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

      snapshot(gopath, til, new_imports, revs)
    end

    revs
  end

  def self.deps_from_imports(imports)
    deps = []
    imports.each do |import|
      next if Go::Package.standard?(import)
      repo_root = Go::RepoRoot.from_import(import)
      deps << repo_root.root
    end

    deps.uniq!
    deps.sort!
  end

  def self.render_nix(revisions)
    NixRenderer.render(revisions)
  end

  class NixRenderer
    def self.render(revisions)
      new.render(revisions)
    end

    def render(revisions)
      template = File.open(TEMPLATE_PATH, &:read)
      renderer = Erubis::Eruby.new(template)
      renderer.result(binding)
    end

    private

    def sha256(rev)
      if rev.root.start_with?("github.com")
        Nix.prefetch_github(owner(rev), repo(rev), rev.rev)
      elsif rev.vcs == "hg"
        Nix.prefetch_hg("http://"+rev.root, rev.rev)
      elsif rev.vcs == "bzr"
        Nix.prefetch_bzr("http://code."+rev.root, rev.rev)
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
