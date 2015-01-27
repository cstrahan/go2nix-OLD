Gem::Specification.new do |s|
  s.name        = 'go2nix'
  s.version     = '0.0.1'
  s.licenses    = ['MIT']
  s.homepage    = 'https://github.com/cstrahan/go2nix'
  s.summary     = "Creates Nix packages from Gemfiles."
  s.description = "Creates Nix packages from Gemfiles."
  s.authors     = [ "Charles Strahan" ]
  s.email       = 'charles.c.strahan@gmail.com'
  s.files       = Dir["bin/*"] + Dir["lib/**/*.rb"]
  s.bindir      = "bin"
  s.executables = [ "go2nix" ]
  s.extensions  = [ "extconf.rb" ]
  s.add_runtime_dependency 'yajl-ruby', '~> 1.2.1'
  s.add_runtime_dependency 'erubis',    '~> 2.7.0'
end
