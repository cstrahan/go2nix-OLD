# About

This utility generates nix package expressions for a given go project.

# Example

This will create a `deps.nix` file for the `ngrok` program, recursively
finding all of its dependencies, where each revisions was made on or
before the date of the given revision (b7d5571aa, which is the 1.7
release of `ngrok`):

``` bash
go2nix --until auto --rev b7d5571aa7f12ac304b8f8286b855cc64dd9bab8 --tags release --pkg github.com/inconshreveable/ngrok --out-nix deps.nix
```

# Usage

    Usage: go2nix [options]
    
    Specific options:
            --pkg PACKAGE                The package to fetch dependencies of
            --until DATE                 The latest revisions to fetch in iso8601 format (e.g. "2014-05-03T00:00:00Z")
            --tags TAGS                  Whitespace separated ist of build tags
            --in-json PATH               Use an existing dependency dump
            --out-json PATH              The path to store the json dependency dump
            --out-nix PATH               The path to store the rendered nix expression
            --rev REVISION               The revision to fetch
        -h, --help                       Show this message
