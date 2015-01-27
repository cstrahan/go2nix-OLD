require 'pp'

# Fake building extension
File.open('Makefile', 'w') { |f| f.write("all:\n\ninstall:\n\n") }
File.open('make', 'w') do |f|
  f.write('#!/bin/sh')
  f.chmod(f.stat.mode | 0111)
end
File.open('wrapper_installer.so', 'w') {}
File.open('wrapper_installer.dll', 'w') {}
File.open('nmake.bat', 'w') { |f| }

def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each { |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    }
  end
  return nil
end

def exe(cmd, default=nil)
  path = which(cmd) || default
  unless path
    raise "Command `#{cmd}' not found on $PATH; please ensure it is in your build environment."
  end

  return path
end

conf_path = File.expand_path("../lib/go2nix/conf.rb", __FILE__)

conf = {
  :go               => exe("go"),
  :go_repo_root     => exe("go-repo-root"),
  :nix_prefetch_zip => exe("nix-prefetch-zip"),
  :nix_prefetch_git => exe("nix-prefetch-git"),
  :nix_prefetch_hg  => exe("nix-prefetch-hg"),
  :nix_prefetch_bzr => exe("nix-prefetch-bzr"),
}

File.open(conf_path, "wb") do |f|
  f.print(pp(conf))
end
