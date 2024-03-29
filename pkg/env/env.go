package env

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
)

type Source interface {
	Get(key string) string
}

// Get will get the value associated with an env key.
func Get(key string) string {
	return os.Getenv(key)
}

func init() {
	var (
		err  error
		cwd  string
		pair []string
	)

	cwd, err = os.Getwd()
	if err != nil {
		log.Println(err)
		return
	}

	env := openenv(cwd)

	if len(env) == 0 {
		return
	}

	for _, keyval := range strings.Split(env, "\n") {
		pair = strings.Split(keyval, "=")
		if len(pair) != 2 {
			fmt.Fprintln(os.Stderr, "must have key value pairs in the .env file")
			continue
		}

		if err = os.Setenv(pair[0], pair[1]); err != nil {
			fmt.Println(err)
		}
	}
}

func openenv(dir string) string {
	file := filepath.Join(dir, ".env")
	b, err := ioutil.ReadFile(file)
	if err != nil {
		log.Println(err)
		return ""
	}

	return string(b)
}
