package web

import (
	"net/http"

	"harrybrown.com/pkg/log"
)

var (
	// DefaultErrorHandler is the default handler that for errors in the server.
	DefaultErrorHandler http.Handler = http.HandlerFunc(NotFound)

	// DefaultNotFoundHandler is the handler that executes if a page or resourse is not found.
	DefaultNotFoundHandler = http.HandlerFunc(NotFound)

	// DefaultHandlerHook is a hook that alows for the modification of handlers at
	// runtime.
	DefaultHandlerHook func(h http.Handler) http.Handler
)

// ServeMux is an interface that defines compatability with the standard library
// http.ServeMux struct.
type ServeMux interface {
	http.Handler
	Handle(path string, handler http.Handler)
	HandleFunc(path string, handler func(http.ResponseWriter, *http.Request))
}

// Router is an http router.
type Router struct {
	mux         ServeMux
	HandlerHook func(http.Handler) http.Handler
}

// NewRouter creates a new router which contains the default http.ServeMux.
func NewRouter() *Router {
	return &Router{
		mux:         new(http.ServeMux),
		HandlerHook: DefaultHandlerHook,
	}
}

func (r *Router) SetMux(m *http.ServeMux) {
	r.mux = m
}

// CreateRouter will make a new router from a ServeMux interface.
func CreateRouter(mux ServeMux) *Router {
	return &Router{
		mux:         mux,
		HandlerHook: DefaultHandlerHook,
	}
}

func (r *Router) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	r.mux.ServeHTTP(rw, req)
}

// Handle registers the a path and a handler using the standard library interface.
func (r *Router) Handle(path string, h http.Handler) {
	r.mux.Handle(path, h)
}

// HandleFunc will register a new route with a HandlerFunc using the standard library interface.
func (r *Router) HandleFunc(path string, fn http.HandlerFunc) {
	r.mux.Handle(path, http.HandlerFunc(fn))
}

// HandleRoute will handle a route.
func (r *Router) HandleRoute(rt Route) {
	var h http.Handler
	nested, err := rt.Expand()

	if err != nil {
		log.Error(err)

		if e, ok := err.(*ErrorHandler); ok {
			h = e
		} else {
			h = DefaultErrorHandler
		}
	} else {
		h = rt.Handler()
	}
	r.mux.Handle(rt.Path(), h)

	if nested != nil {
		r.HandleRoutes(nested)
	}
}

// HandleRoutes will handle a list of routes.
func (r *Router) HandleRoutes(routes []Route) {
	for _, rt := range routes {
		r.HandleRoute(rt)
	}
}

// AddRoute adds a route to the Router.
func (r *Router) AddRoute(path string, h http.Handler) {
	r.HandleRoute(NewRoute(path, h))
}

// AddRouteFunc adds a route to the Router from a function.
func (r *Router) AddRouteFunc(path string, h http.HandlerFunc) {
	r.HandleRoute(NewRouteFunc(path, h))
}

var _ http.Handler = (*Router)(nil)
