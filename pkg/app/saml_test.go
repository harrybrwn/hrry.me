package app

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"testing"

	"github.com/crewjam/saml/samlsp"
	"github.com/matryer/is"
)

func TestSAMLServer(t *testing.T) {
	is := is.New(t)
	const certFile = "../../config/pki/saml/saml.crt"
	const keyFile = "../../config/pki/saml/saml.key"
	os.Setenv("API_SAML_CERT_FILE", certFile)
	os.Setenv("API_SAML_KEY_FILE", keyFile)
	os.Setenv("API_SAML_HOST", "api.hrry.test")
	svc, err := NewSAMLService(&SAMLOptions{
		Host: "localhost:8080",
		// Path:     "/",
		Insecure: true,
	})
	is.NoErr(err)
	mux := http.NewServeMux()
	mux.Handle("/hello", svc.mw.RequireAccount(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		displayName := samlsp.AttributeFromContext(r.Context(), "displayName")
		fmt.Fprintf(w, "Hello, %s!", displayName)
	})))
	mux.Handle("/api/saml/", svc.mw)
	_ = http.ListenAndServe(":8080", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var sr = statusResp{w, 0}
		mux.ServeHTTP(&sr, r)
		fmt.Println(sr.status, r.Method, r.URL.Path)
	}))
}

type statusResp struct {
	http.ResponseWriter
	status int
}

func (sr *statusResp) WriteHeader(statusCode int) {
	sr.status = statusCode
	sr.ResponseWriter.WriteHeader(statusCode)
}

func TestSAMLService(t *testing.T) {
	is := is.New(t)
	// idpMetadataURL, err := url.Parse("https://samltest.id/saml/idp")
	// is.NoErr(err)
	// idpMetadata, err := samlsp.FetchMetadata(context.Background(), http.DefaultClient,
	// 	*idpMetadataURL)
	// is.NoErr(err)
	// fmt.Printf("%+v\n", idpMetadata)

	const certFile = "../../config/pki/saml/saml.crt"
	const keyFile = "../../config/pki/saml/saml.key"
	os.Setenv("API_SAML_CERT_FILE", certFile)
	os.Setenv("API_SAML_KEY_FILE", keyFile)
	os.Setenv("API_SAML_HOST", "api.hrry.test")
	svc, err := NewSAMLService(nil)
	is.NoErr(err)
	is.Equal(svc.SloURL().Path, "/api/saml/slo")
	is.Equal(svc.MetadataURL().Path, "/api/saml/metadata")
	is.Equal(svc.AcsURL().Path, "/api/saml/acs")

	idpMetadataURL, err := url.Parse("https://sptest.iamshowcase.com/testsp_metadata.xml")
	is.NoErr(err)
	idpMetadata, err := samlsp.FetchMetadata(context.Background(), http.DefaultClient, *idpMetadataURL)
	is.NoErr(err)
	svc.mw.ServiceProvider.IDPMetadata = idpMetadata

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/", nil)
	svc.mw.ServeMetadata(rec, req)
	is.Equal(rec.Code, 200)
	is.Equal(rec.Header().Get("Content-Type"), "application/samlmetadata+xml")
	rec = httptest.NewRecorder()
	req = httptest.NewRequest("GET", "/", nil)
	// svc.mw.ServeACS(rec, req)
	svc.mw.ServeMetadata(rec, req)

	// fmt.Println(rec.Code, http.StatusText(rec.Code))
	// fmt.Println(rec.Header())
	// fmt.Println(rec.Body.String())
	metadata, err := samlsp.ParseMetadata(rec.Body.Bytes())
	is.NoErr(err)
	fmt.Printf("%+v\n", metadata)
}
