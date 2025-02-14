// Binary gntl fetches .tl schema from remote repo.
package main

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path"
	"strconv"
	"strings"

	"github.com/TGoCall/tl"
)

func mergeSchema(target, s *tl.Schema) {
Definitions:
	for _, d := range s.Definitions {
		for _, targetD := range target.Definitions {
			if targetD.Definition.ID == d.Definition.ID {
				continue Definitions
			}
		}

		target.Definitions = append(target.Definitions, d)
	}
Classes:
	for _, c := range s.Classes {
		for _, targetC := range target.Classes {
			if targetC.Name == c.Name {
				continue Classes
			}
		}

		target.Classes = append(target.Classes, c)
	}
	if target.Layer == 0 {
		target.Layer = s.Layer
	}
}

func main() {
	var (
		name   = flag.String("f", "telegram_api.tl", "file name to download; api.tl or mtproto.tl")
		base   = flag.String("base", "https://raw.githubusercontent.com/tdlib/td", "base url")
		branch = flag.String("branch", "master", "branch to use")
		dir    = flag.String("dir", "td/generate/scheme", "directory of schemas")
		out    = flag.String("o", "", "output file name (blank to stdout)")
		merge  = flag.String("merge", "", "path to schema(s) to merge with, comma-separated")
	)
	flag.Parse()

	u, err := url.Parse(*base)
	if err != nil {
		panic(err)
	}

	u.Path = path.Join(u.Path, *branch, *dir, *name)

	res, err := http.Get(u.String())
	if err != nil {
		panic(err)
	}
	defer func() { _ = res.Body.Close() }()
	if res.StatusCode/100 != 2 {
		panic(fmt.Sprintf("status code %d", res.StatusCode))
	}

	// Parsing in-place.
	h := sha256.New()
	s, err := tl.Parse(io.TeeReader(res.Body, h))
	if err != nil {
		panic(err)
	}

	if *merge != "" {
		for _, mergeName := range strings.Split(*merge, ",") {
			data, err := os.ReadFile(mergeName)
			if err != nil {
				panic(err)
			}

			m, err := tl.Parse(bytes.NewReader(data))
			if err != nil {
				panic(err)
			}

			mergeSchema(s, m)
		}
	}

	// Trying to detect layer of tdlib schema.
	if s.Layer == 0 && *name == "telegram_api.tl" {
		layerURL, err := url.Parse(*base)
		if err != nil {
			panic(err)
		}
		layerURL.Path = path.Join(layerURL.Path, *branch, "td/telegram/Version.h")
		res, err := http.Get(layerURL.String())
		if err != nil {
			panic(err)
		}
		if res.StatusCode == http.StatusOK {
			scanner := bufio.NewScanner(res.Body)
			for scanner.Scan() {
				t := strings.TrimSpace(scanner.Text())
				// constexpr int32 MTPROTO_LAYER = 131;
				const (
					prefix = `constexpr int32 MTPROTO_LAYER = `
					suffix = `;`
				)
				if !strings.HasPrefix(t, prefix) {
					continue
				}
				t = strings.TrimPrefix(t, prefix)
				t = strings.TrimSuffix(t, suffix)
				t = strings.TrimSpace(t)
				if layer, err := strconv.Atoi(t); err == nil {
					s.Layer = layer
				}
			}
		}
	}
	if s.Layer == 0 && *name == "telegram_api.tl" {
		// Still failed.
		panic("failed to detect layer")
	}

	var outWriter io.Writer = os.Stdout
	if *out != "" {
		w, err := os.Create(*out)
		if err != nil {
			panic(err)
		}
		defer func() {
			if err := w.Close(); err != nil {
				panic(err)
			}
		}()
		outWriter = w
	}

	// Writing header to avoid manual edit.
	var b strings.Builder
	b.WriteString("// Code generated by gntl, DO NOT EDIT.\n")
	b.WriteString("//\n")
	b.WriteString(fmt.Sprintf("// Source: %s\n", u))
	if *merge != "" {
		b.WriteString(fmt.Sprintf("// Merge:  %s\n", *merge))
	}
	if s.Layer > 0 {
		b.WriteString(fmt.Sprintf("// Layer:  %d\n", s.Layer))
	}
	b.WriteString(fmt.Sprintf("// SHA256: %x\n", h.Sum(nil)))
	b.WriteRune('\n')
	if _, err := io.WriteString(outWriter, b.String()); err != nil {
		panic(err)
	}

	if _, err := s.WriteTo(outWriter); err != nil {
		panic(err)
	}
}
