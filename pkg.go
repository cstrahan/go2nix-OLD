package main

import (
  "encoding/json"
  "io"
  "os"
  "os/exec"
)

type Package struct {
  Dir        string
  Root       string
  ImportPath string
  Deps       []string
  Standard   bool

  GoFiles        []string
  CgoFiles       []string
  IgnoredGoFiles []string

  TestGoFiles  []string
  TestImports  []string
  XTestGoFiles []string
  XTestImports []string

  Error struct {
    Err string
  }
}

func isStandard(name string) bool {
  dummy, _ := os.Getwd()
  pkgs, _ := loadPackages(dummy, name)
  if len(pkgs) > 0 {
    pkg := pkgs[0]
    return pkg.Standard
  }
  return false
}

func allImports(pkgs []Package) []string {
  allSet := make(map[string]bool)
  for _, p := range pkgs {
    for _, i := range p.Deps {
      allSet[i] = true
    }
    for _, i := range p.TestImports {
      allSet[i] = true
    }
    for _, i := range p.XTestImports {
      allSet[i] = true
    }
  }

  all := make([]string, 0)
  for i, _ := range allSet {
    all = append(all, i)
  }

  return all
}

func loadPackages(gopath string, name ...string) (a []Package, err error) {
  if len(name) == 0 {
    return nil, nil
  }
  args := []string{"list", "-e", "-json"}
  cmd := exec.Command("go", append(args, name...)...)
  cmd.Env = append(envNoGopath(), "GOPATH="+gopath)
  r, err := cmd.StdoutPipe()
  if err != nil {
    return nil, err
  }
  cmd.Stderr = os.Stderr
  err = cmd.Start()
  if err != nil {
    return nil, err
  }
  d := json.NewDecoder(r)
  for {
    info := new(Package)
    err = d.Decode(info)
    if err == io.EOF {
      break
    }
    if err != nil {
      info.Error.Err = err.Error()
    }
    a = append(a, *info)
  }
  err = cmd.Wait()
  if err != nil {
    return nil, err
  }
  return a, nil
}

func (p *Package) allGoFiles() (a []string) {
  a = append(a, p.GoFiles...)
  a = append(a, p.CgoFiles...)
  a = append(a, p.TestGoFiles...)
  a = append(a, p.XTestGoFiles...)
  a = append(a, p.IgnoredGoFiles...)
  return a
}
