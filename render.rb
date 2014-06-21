#!/usr/bin/env ruby
require 'json'



# git = desc: fetchgit { url = "https://${desc.dir}/${desc.name}";
                       # inherit (desc) rev sha256; };
def render_github(root, rev)
  owner = root[/github.com\/([^\/]+)\/.*/, 1]
  repo = root[/github.com\/[^\/]+\/([^\/]+)/, 1]
  # url = "http://github.com/#{owner}/#{repo}/archive/#{rev}.tar.gz"
  # sha = `nix-prefetch-zip --base32 --url "#{url}" 2>/dev/null`.chomp
  sha = nil

  puts <<-CODE
  src = fetchFromGitHub {
    owner = "#{owner}";
    repo = "#{repo}";
    rev = "#{rev}";
    sha256 = "#{sha}";
  };
  CODE
end

def render_git(root, rev)
  puts <<-CODE
git = desc: fetchgit { url = "https://${desc.dir}/${desc.name}";
                       inherit (desc) rev sha256; };
hg = desc: fetchhg { url = "https://${desc.dir}/${desc.name}";
                     tag = desc.rev;
                     inherit (desc) sha256; };

src = fetchbzr {
  url = "https://code.launchpad.net/~kicad-stable-committers/kicad/stable";
  revision = 4024;
  sha256 = "1sv1l2zpbn6439ccz50p05hvqg6j551aqra551wck9h3929ghly5";
};
CODE
end

def render_bzr(root, rev)
end

def render_hg(root, rev)
end

puts <<-PRELUDE
{ stdenv, go, fetchhg, fetchbzr, fetchgit, fetchFromGitHub }:

let
  inherit (stdenv) lib;
  lib.replaceChars = del: new: s:
  mkGoLib = args@{ rootPath, src }: stdenv.mkDerivation ({
    name = replaceChars ["/"] ["_"] rootPath;
    buildInputs = [ go ];
    buildCommand = ''
      GOPATH=$out/go
      ensureDir "$GOPATH/src/$rootPath"
      cp -r $src "$GOPATH/src/$rootPath"
      cp -r $src "$GOPATH/src/$rootPath"
      go install ./...
    '';
  } // args)
  
PRELUDE
deps = JSON.parse(File.open("deps.json", &:read))
deps.each do |dep|
  root = dep["Root"]
  rev  = dep["Rev"]
  vcs  = dep["VCS"]

  if vcs == "git"
    render_github(root, rev)
  # elsif vcs == "bzr"
    # render_bzr(root, rev)
  # elsif vcs == "hg"
    # render_hg(root, rev)
  end
end
