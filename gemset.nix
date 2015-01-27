{
  "erubis" = {
    version = "2.7.0";
    source = {
      type = "gem";
      sha256 = "1fj827xqjs91yqsydf0zmfyw9p4l2jz5yikg3mppz6d7fi8kyrb3";
    };
  };
  "go2nix" = {
    version = "0.0.1";
    source = {
      type = "path";
      path = ./.;
    };
    dependencies = [
      "erubis"
      "yajl-ruby"
    ];
  };
  "yajl-ruby" = {
    version = "1.2.1";
    source = {
      type = "gem";
      sha256 = "0zvvb7i1bl98k3zkdrnx9vasq0rp2cyy5n7p9804dqs4fz9xh9vf";
    };
  };
}