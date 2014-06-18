package main

import (
  "bytes"
  "code.google.com/p/go.tools/go/vcs"
  "encoding/json"
  "fmt"
  "os"
  "os/exec"
  "path/filepath"
  "strings"
  "time"
)

const (
  bzrDateFormat = "Mon 2006-01-02 15:04:05 -0700"
)

func main() {
  dir := os.Args[1]
  dir, _ = filepath.Abs(dir)
  os.MkdirAll(dir, 0700)

  until, _ := time.Parse(time.RFC3339Nano, "2014-06-13T16:26:28+00:00")
  init := "github.com/mitchellh/packer"
  revs := goGetAll(dir, until, []string{init})
  println(toJson(revs))
}

func goGetAll(dir string, until time.Time, imports []string) []Revision {
  revs := make([]Revision, 0)
  for _, importPath := range imports {
    if isStandard(importPath) {
      continue
    }

    repo, err := vcs.RepoRootForImportPath(importPath, true)
    if err != nil {
      continue
    }

    if !isDir(dir + "/src/" + repo.Root) {
      println(repo.Root)

      // fetch source
      cmd := exec.Command("go", "get", importPath)
      cmd.Env = append(envNoGopath(), "GOPATH="+dir)
      cmd.Dir = dir
      err := cmd.Run()
      _ = err

      // find revision
      rev := findRevision(repo.VCS.Cmd, dir+"/src/"+repo.Root, until)

      // set revision back
      sh(dir+"/src/"+repo.Root, substTag(repo.VCS.Cmd+" "+repo.VCS.TagSyncCmd, rev), true)

      // recurse
      pkgs, _ := loadPackages(dir, repo.Root+"...")
      newImports := allImports(pkgs)
      // printJson(newImports)
      newRevs := goGetAll(dir, until, newImports)
      revs = append(revs, newRevs...)
      revs = append(revs, Revision{root: repo.Root, rev: rev})
    }
  }

  return revs
}

func isDir(path string) bool {
  if fs, err := os.Stat(path); err == nil {
    return fs.IsDir()
  }

  return false
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

type Revision struct {
  root string
  rev  string
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
