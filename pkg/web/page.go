package web

import (
	"bytes"
	"html/template"
	"io"
	"net/http"
	"path/filepath"

	"gopkg.hrry.dev/homelab/pkg/log"
)

var (
	// TemplateDir is a variable that can be set by the importer of this
	// library to as a prefix to any template files given to functions or
	// structs in this package.
	TemplateDir string

	// BaseTemplates is a variable that holds template file names that all
	// pages will use.
	BaseTemplates []string

	// BaseTemplateName is the name of the template that will be executed first
	// when a batch of templates are executed. (default "base")
	BaseTemplateName = "base"
)

// Page is a struct that represents a webpage
type Page struct {
	// the title of the web page
	Title string

	// Template is the main template used for the web page.
	Template string

	// RoutePath is the route used when serving the page.
	RoutePath string

	// Serve is a function used to serve http requests and will override the
	// default behavior of the page. If the Serve field is not given the Page
	// will execute it's internal template blob and serve that.
	Serve func(w http.ResponseWriter, r *http.Request)

	// RequestHook is a handler function that alows users to modify the response or the page.
	// Runs once for every request to the page.
	RequestHook func(self *Page, w http.ResponseWriter, r *http.Request)

	// Data is an interface used as a vessel for getting data into the web
	// page template.
	Data interface{}

	// HotReload is a boolean that, if true, will cause the Page to call 'Init'
	// everytime it is written to an io.Writer. If there is no Serve function
	// set, then the page will be doing file IO upon every request.
	HotReload bool

	templates    []string
	blob         *template.Template
	baseTmplName string
}

// WriteTo will write the webpage to an io.Writer
func (p *Page) WriteTo(w io.Writer) (int64, error) {
	if p.blob == nil {
		return 0, Errorf(500, "Templates for '%s' are uninitialized", p.Title)
	}

	b := &bytes.Buffer{}
	err := p.blob.ExecuteTemplate(b, p.baseTmplName, p)
	if err != nil {
		return 0, Errorf(500, "Template Error: %s", err.Error())
	}

	n, err := w.Write(b.Bytes())
	return int64(n), err
}

// ServerHTTP lets the Page struct implement the http.Handler interface.
func (p *Page) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if p.HotReload {
		if err := p.init(); err != nil {
			log.Error(err)
		}
	}
	if p.RequestHook != nil {
		p.RequestHook(p, w, r)
	}

	if p.Serve != nil {
		p.Serve(w, r)
		return
	}
	if _, err := p.WriteTo(w); err != nil {
		if e, ok := err.(*ErrorHandler); ok {
			e.ServeHTTP(w, r)
		} else {
			ServeErrorMsg(w, err.Error(), 500)
		}
		log.Error(err)
	}
}

// Path returns the route path.
func (p *Page) Path() string {
	return p.RoutePath
}

// Handler returns the page that the method was called from.
func (p *Page) Handler() http.Handler {
	return p
}

// Expand returns nothing because a webpage cannont be expanded.
func (p *Page) Expand() ([]Route, error) {
	if err := p.init(); err != nil {
		return nil, err
	}
	return nil, nil
}

func (p *Page) init() error {
	var err error
	if len(p.templates) == 0 {
		p.templates = p.tmpls()
	}
	p.baseTmplName = BaseTemplateName
	p.blob, err = template.New(p.baseTmplName).ParseFiles(p.templates...)
	if err != nil {
		return Errorf(http.StatusInternalServerError, "Template Error: %s", err.Error())
	}
	return nil
}

// Used a lot in testing.
func (p *Page) settemplate(name string, data string) (err error) {
	p.baseTmplName = name
	p.blob = template.New(p.baseTmplName)
	p.blob, err = p.blob.Parse(data)
	return err
}

func (p *Page) tmpls() []string {
	var (
		i      = 0
		length = len(BaseTemplates) + 1
	)

	tmpls := make([]string, length)
	if len(p.Template) > 0 {
		tmpls[i] = getfile(p.Template)
		i++
	}
	for k, t := range BaseTemplates {
		tmpls[k+i] = getfile(t)
	}
	return tmpls
}

func (p *Page) templateCount() int {
	n := len(BaseTemplates) + len(p.templates)
	if len(p.Template) > 0 {
		n++
	}
	return n
}

var (
	_ http.Handler = (*Page)(nil)
	_ Route        = (*Page)(nil)
	_ io.WriterTo  = (*Page)(nil)
)

func getfile(name string) string {
	if len(TemplateDir) < 1 {
		return name
	}
	return filepath.Join(TemplateDir, name)
}
