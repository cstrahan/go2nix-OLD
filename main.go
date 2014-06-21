package main

import (
  "bytes"
  "code.google.com/p/go.tools/go/vcs"
  "encoding/json"
  "flag"
  "fmt"
  "io/ioutil"
  "os"
  "os/exec"
  "path/filepath"
  "regexp"
  "strings"
  "time"
)

const (
  bzrDateFormat = "Mon 2006-01-02 15:04:05 -0700"
)

// 2008-09-08T15:47:31Z
var (
  pkgFlag   = flag.String("pkg", "", "the package to fetch")
  outFlag   = flag.String("out", "deps.json", "the path to dump the dependencies to")
  inFlag    = flag.String("in", "", "the dumped dependencies to create a nix expression from")
  untilFlag = flag.String("until", "", "the date/time in RFC3338 format")
)

func main() {
  flag.Parse()

  // println(githubHash("mitchellh", "cli", "df3e8ad8d1c"))
  // os.Exit(0)
  if *inFlag == "" {
    gopath := "dump"
    gopath, _ = filepath.Abs(gopath)
    os.MkdirAll(gopath, 0700)
    until, _ := time.Parse(time.RFC3339Nano, *untilFlag)
    println("-----------------")
    println(toJson(*untilFlag))
    println(toJson(*pkgFlag))
    println(toJson(*outFlag))
    println(toJson(until))
    println("-----------------")
    pkg := *pkgFlag
    outPath := *outFlag

    do_dump(gopath, until, pkg, outPath)
  } else {
    inPath := *inFlag
    outPath := *outFlag

    do_nix(inPath, outPath)
  }
}

func do_dump(dir string, until time.Time, pkg string, outPath string) {
  // println(dir)
  // println(toJson(until))
  // println(toJson(pkg))
  revs := goGetAll(dir, until, []string{pkg})
  println("**A")
  json := toJson(revs)
  ioutil.WriteFile(outPath, []byte(json), 0644)
  fmt.Fprint(os.Stdout, json)
}

//  git = desc: fetchgit { url = "https://${desc.dir}/${desc.name}";
//                         inherit (desc) rev sha256; };
//  hg = desc: fetchhg { url = "https://${desc.dir}/${desc.name}";
//                       tag = desc.rev;
//                       inherit (desc) sha256; };

//  src = fetchbzr {
//    url = "https://code.launchpad.net/~kicad-stable-committers/kicad/stable";
//    revision = 4024;
//    sha256 = "1sv1l2zpbn6439ccz50p05hvqg6j551aqra551wck9h3929ghly5";
//  };
func do_nix(inPath string, outPath string) {
  jsonStr, _ := ioutil.ReadFile(inPath)
  deps := make([]Revision, 0)
  json.Unmarshal(jsonStr, deps)
  println(toJson(deps))
}

func githubHash(owner string, repo string, rev string) string {
  tmpPath := "temp.nix"
  kvs := map[string]string{"owner": owner, "repo": repo, "rev": rev}
  nixExpr := expand(kvs, `
    (import <nixpkgs> { }).fetchFromGitHub {
      owner = "{owner}";
      repo = "{repo}";
      rev = "{rev}";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    }
  `)
  ioutil.WriteFile(tmpPath, []byte(nixExpr), 0644)

  pwd, _ := os.Getwd()
  stderr, _ := sh(pwd, "nix-build "+tmpPath+" 2>&1 1>/dev/null || true", true)
  regexp := regexp.MustCompile("instead has `([^']+)'")
  hash := regexp.FindStringSubmatch(stderr)[1]
  return hash
}

func goGetAll(gopath string, until time.Time, imports []string) []Revision {
  revs := make([]Revision, 0)
  for _, importPath := range imports {
    if isStandard(importPath) {
      continue
    }

    repo, err := vcs.RepoRootForImportPath(importPath, true)
    if err != nil {
      continue
    }

    if !isDir(gopath + "/src/" + repo.Root) {
      println(repo.Root)

      // fetch source
      cmd := exec.Command("go", "get", importPath)
      cmd.Env = append(envNoGopath(), "GOPATH="+gopath)
      cmd.Dir = gopath
      err := cmd.Run()
      _ = err

      // find revision
      rev := findRevision(repo.VCS.Cmd, gopath+"/src/"+repo.Root, until)

      // set revision back
      sh(gopath+"/src/"+repo.Root, substTag(repo.VCS.Cmd+" "+repo.VCS.TagSyncCmd, rev), true)

      // recurse
      pkgs, _ := loadPackages(gopath, repo.Root+"...")
      newImports := allImports(pkgs)
      // printJson(newImports)
      newRevs := goGetAll(gopath, until, newImports)
      revs = append(revs, newRevs...)
      revs = append(revs, Revision{Root: repo.Root, Rev: rev, VCS: repo.VCS.Cmd, Deps: depsFromImports(newImports)})
    }
  }

  return revs
}

func depsFromImports(imports []string) []string {
  all := make([]string, 0)
  for _, imp := range imports {
    if !isStandard(imp) {
      repo, _ := vcs.RepoRootForImportPath(imp, true)
      if repo == nil {
        println("NULL IMPORT")
        println(imp)
      } else {
        all = append(all, repo.Root)
      }
    }
  }

  return uniqueStrings(all)
}

func isDir(path string) bool {
  if fs, err := os.Stat(path); err == nil {
    return fs.IsDir()
  }

  return false
}

func uniqueStrings(strs []string) []string {
  set := make(map[string]bool)
  for _, str := range strs {
    set[str] = true
  }

  unique := make([]string, 0)
  for str, _ := range set {
    unique = append(unique, str)
  }

  return unique
}

func findRevision(cmd string, dir string, until time.Time) string {
  rev := ""
  time := until.Format("2006-01-02 15:04:05")
  switch cmd {
  case "bzr":
    rev = findBzrRevision(dir, until)
  case "git":
    rev, _ = sh(dir, "git log --until '"+time+"' --pretty=format:'%H' -n1", true)
  case "hg":
    rev, _ = sh(dir, "hg log -r \"sort(date('<"+time+"'), -rev)\" --template '{rev}\n' --limit 1", true)
  case "svn":
    panic("UH-OH! SVN isn't supported yet!!!!!")
    rev = ""
  }

  return trim(rev)
}

// This is fucking ridiculous.
type Revision struct {
  Root string
  Rev  string
  VCS  string
  Deps []string // Root names
}

func envNoGopath() (a []string) {
  for _, s := range os.Environ() {
    if !strings.HasPrefix(s, "GOPATH=") {
      a = append(a, s)
    }
  }
  return a
}

func trim(str string) string {
  return strings.Trim(str, " \n\t")
}

func findBzrRevision(dir string, until time.Time) string {
  out, _ := sh(dir, "bzr log --log-format=long", true)

  var revno string
  for _, l := range strings.Split(out, "\n") {
    parts := strings.SplitN(l, " ", 2)
    if len(parts) == 2 {
      switch parts[0] {
      case "revno:":
        revno = strings.SplitN(parts[1], " ", 2)[0]
      case "timestamp:":
        date, _ := time.Parse(bzrDateFormat, parts[1])
        if date.Before(until) {
          return revno
        }
      }
    }
  }

  return ""
}

func sh(dir string, cmdline string, verbose bool) (string, error) {
  cmd := exec.Command("sh", "-c", cmdline)
  cmd.Dir = dir
  var buf bytes.Buffer
  cmd.Stdout = &buf
  cmd.Stderr = &buf
  err := cmd.Run()
  out := buf.Bytes()
  if err != nil {
    if verbose {
      fmt.Fprintf(os.Stderr, "# cd %s; %s\n", dir, cmdline)
      os.Stderr.Write(out)
    }
    return "", err
  }
  return string(out), nil
}

func substTag(str string, tag string) string {
  return expand(map[string]string{"tag": tag}, str)
}

func expand(m map[string]string, s string) string {
  for k, v := range m {
    s = strings.Replace(s, "{"+k+"}", v, -1)
  }
  return s
}

func toJson(v interface{}) string {
  out, _ := json.MarshalIndent(v, "", "  ")
  return string(out)
}

func printJson(v interface{}) {
  out, _ := json.MarshalIndent(v, "", "  ")
  fmt.Println(string(out))
}
