require 'shellwords'
require 'tmpdir'

module Go2nix
  module Nix
    def self.prefetch_github(owner, repo, rev)
      url = "https://github.com/#{owner}/#{repo}/archive/#{rev}.tar.gz"
      `nix-prefetch-zip --base32 --url #{url.shellescape} 2>/dev/null`.chomp
    end

    def self.prefetch_git(repo, rev)
      `hashFormat="--base32" nix-prefetch-git #{repo.shellescape} #{rev.shellescape} 2>/dev/null`.split("\n")[-1]
    end

    def self.prefetch_hg(repo, rev)
      `nix-prefetch-hg #{repo.shellescape} #{rev.shellescape} 2>/dev/null`.split("\n")[1]
    end

    def self.prefetch_bzr(repo, rev)
      `nix-prefetch-bzr #{repo.shellescape} #{rev.shellescape} 2>/dev/null`.split("\n")[1]
    end
  end
end
