with import <nixpkgs> {};

let
  erubis = buildRubyGem {
    inherit ruby;
    gemName = "erubis";
    version = "2.7.0";
    sha256 = "1fj827xqjs91yqsydf0zmfyw9p4l2jz5yikg3mppz6d7fi8kyrb3";
  };

  yajl = buildRubyGem {
    inherit ruby;
    gemName = "yajl-ruby";
    version = "1.2.1";
    sha256 = "0zvvb7i1bl98k3zkdrnx9vasq0rp2cyy5n7p9804dqs4fz9xh9vf";
  };
in
stdenv.mkDerivation rec {
  name = "go2nix";

  src = ".";

  buildInputs = [
    ruby erubis yajl go go-repo-root
    nix-prefetch-scripts
    git mercurial bazaar subversion
  ];

  installPhase = ''
    cp -r $src $out
    chmod +x $out/bin/go2nix
  '';
}
