package main

import (
	"errors"
	"fmt"
	"strings"

	"gopkg.in/yaml.v3"
)

type Validatable interface {
	Validate() error
}

type Configurable interface {
	Calc(*K8sGenConfig)
}

type K8sGenConfig struct {
	Images    ImagesConfig `json:"images"`
	Reloader  bool         `json:"reloader"`
	Resources ResourceSizesConfig
	Apps      map[string]*App
}

type ImagesConfig struct {
	Registry string `json:"registry"`
	User     string `json:"user"`
}

// Calc will do it's best to use the existing values to calculate any missing
// values.
func (kc *K8sGenConfig) Calc() {
	for name, app := range kc.Apps {
		if len(app.Name) == 0 {
			app.Name = name
		}
		app.Calc(kc)
	}
}

func (kc *K8sGenConfig) Validate() error {
	for name, app := range kc.Apps {
		err := app.Validate()
		if err != nil {
			return fmt.Errorf("validation for app %q failed: %w", name, err)
		}
	}
	return nil
}

type Size uint8

const (
	SizeUnknown Size = iota
	SizeBig
	SizeMed
	SizeSml
)

func NewSize(v string) Size {
	switch strings.ToLower(strings.Trim(v, " \n\t\r")) {
	case "l", "b", "lg", "bg", "big", "lrg", "large":
		return SizeBig
	case "m", "med", "medium":
		return SizeMed
	case "s", "sm", "sml", "small":
		return SizeSml
	default:
		return SizeUnknown
	}
}

func (s Size) String() string {
	switch s {
	case SizeBig:
		return "big"
	case SizeMed:
		return "medium"
	case SizeSml:
		return "small"
	default:
		return "<unknown>"
	}
}

func (s *Size) UnmarshalText(text []byte) error {
	size := NewSize(string(text))
	if size == SizeUnknown {
		return errors.New("unknown size")
	}
	*s = size
	return nil
}

func (s *Size) MarshalYAML() (any, error) {
	return s.String(), nil
}

type Image struct {
	Registry string
	Name     string
	Tag      string
}

func ParseImage(s string) (*Image, error) {
	var img Image
	err := parseImage(&img, s)
	if err != nil {
		return nil, err
	}
	return &img, nil
}

func (img *Image) Validate() error {
	if len(img.Name) == 0 {
		return errors.New("image name is required")
	}
	if len(img.Tag) == 0 {
		return errors.New("image version tag is required")
	}
	return nil
}

func (img *Image) String() string {
	if len(img.Registry) == 0 {
		return fmt.Sprintf("%s:%s", img.Name, img.Tag)
	}
	return fmt.Sprintf("%s/%s:%s", img.Registry, img.Name, img.Tag)
}

func (img *Image) UnmarshalYAML(val *yaml.Node) error {
	switch val.Kind {
	case yaml.MappingNode:
		for i := 1; i < len(val.Content); i++ {
			k := val.Content[i-1]
			v := val.Content[i]
			switch k.Value {
			case "registry":
				img.Registry = v.Value
			case "name":
				img.Name = v.Value
			case "tag":
				img.Tag = v.Value
			}
		}
		return nil
	case yaml.ScalarNode:
		return parseImage(img, val.Value)
	default:
		return errors.New("invalid node type")
	}
}

func (img *Image) UnmarshalText(text []byte) error {
	return parseImage(img, string(text))
}

func (img *Image) empty() bool {
	return len(img.Name) == 0 && len(img.Registry) == 0
}

var errEmptyImageString = errors.New("empty image")

func parseImage(img *Image, s string) error {
	if len(s) == 0 {
		return errEmptyImageString
	}
	if strings.Count(s, "/") > 1 {
		ix := strings.IndexByte(s, '/')
		img.Registry = s[:ix]
		s = s[ix+1:]
	}
	ix := strings.LastIndexByte(s, ':')
	if ix > 0 {
		img.Tag = s[ix+1:]
		s = s[:ix]
	}
	img.Name = s
	return nil
}
