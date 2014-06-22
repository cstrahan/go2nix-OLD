require 'go2nix/go'
require 'go2nix/revision'
require 'go2nix/vcs'

module Go2nix
  def self.snapshot(gopath, til, imports, revs=[])
    imports.each do |import|
      next if Go::Package.standard?(import)

      repo_root = Go::RepoRoot.from_import(import) rescue nil
      vcs = repo_root.vcs
      root = repo_root.root
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

      pkgs = Go::Package.from_import(gopath, "#{root}...")
      new_imports = Go::Package.all_imports(pkgs)
      deps = deps_from_imports(new_imports)
      deps.delete(root)

      revs << Revision.new(
        :root => root,
        :rev => rev,
        :vcs => vcs.cmd,
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

    deps.uniq!.sort!
  end
end
