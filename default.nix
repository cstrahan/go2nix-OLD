with import <nixpkgs> {};

stdenv.mkDerivation {
  name = "go2nix";

  src = ./.;

  buildInputs = with rubyLibs; [
    ruby yajl_ruby erubis
    go go-repo-root
    git mercurial bazaar subversion
  ];

  installPhase = ''
    cp -r $src $out
    chmod -R +w $out

    mv $out/bin/{,.}go2nix
    cat <<EOF > $out/bin/go2nix
    #!/bin/sh
    export PATH=${lib.makeSearchPath "bin" [ ruby go go-repo-root git mercurial bazaar subversion nix-prefetch-scripts nix ]}:$PATH
    export GIT_SSL_CAINFO="${cacert}/etc/ca-bundle.crt"
    export RUBYOPT=rubygems
    export GEM_PATH=${lib.makeSearchPath ruby.gemPath (with rubyLibs; [ yajl_ruby erubis ])}

    ruby $out/bin/.go2nix "\$@"
    EOF
    chmod +x $out/bin/go2nix
  '';
}
