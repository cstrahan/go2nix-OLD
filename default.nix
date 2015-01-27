with import <nixpkgs> {};

bundlerEnv {
  name = "go2nix-0.0.1";
  gemfile = ./Gemfile;
  lockfile = ./Gemfile.lock;
  gemset = ./gemset.nix;
  gemConfig = defaultGemConfig // {
    go2nix = attrs: {
      buildInputs = [ go go-repo-root git mercurial bazaar subversion ];
    };
  };
}
