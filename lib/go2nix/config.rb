module Go2nix
  conf_file = File.expand_path("../conf.rb", __FILE__)
  conf = eval(File.read(conf_file))
  Config = Struct.new(*conf.keys).new(*conf.values)
end
