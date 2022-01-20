package app

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	mathrand "math/rand"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"github.com/golang/mock/gomock"
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/matryer/is"
	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	"golang.org/x/crypto/bcrypt"
	"harrybrown.com/internal/mocks/mockdb"
	"harrybrown.com/internal/mockutil"
	"harrybrown.com/pkg/auth"
)

func init() {
	logger.SetLevel(logrus.ErrorLevel)
}

func TestHits(t *testing.T) {
	var (
		is   = is.New(t)
		ctrl = gomock.NewController(t)
		db   = mockdb.NewMockDB(ctrl)
		rows = mockdb.NewMockRows(ctrl)
		e    = echo.New()
		ctx  = context.Background()
	)
	defer ctrl.Finish()
	defer silent()()
	type table struct {
		u string
	}
	for _, tab := range []table{
		{u: "/api/test"},
		{u: "/"},
		{u: ""},
	} {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest("GET", "/api/hits", nil).WithContext(ctx)
		c := e.NewContext(req, rec)
		c.QueryParams().Set("u", tab.u)
		exp := tab.u
		if exp == "" {
			exp = "/"
		}
		db.EXPECT().QueryContext(ctx, hitsQuery, exp).Return(rows, nil)
		rows.EXPECT().Next().Return(true)
		rows.EXPECT().Scan(gomock.Any()).Return(nil)
		rows.EXPECT().Close().Return(nil).Times(1)
		is.NoErr(Hits(db)(c))
		is.Equal(rec.Code, 200)
		is.True(strings.HasPrefix(rec.Header().Get("Content-Type"), "application/json"))
		is.Equal("{\"count\":0}\n", rec.Body.String())
	}
}

var (
	intptr      *int
	strptr      *string
	bytesptr    *[]byte
	durationPtr *time.Duration
)

func TestTokenHandler(t *testing.T) {
	defer silent()()
	var (
		ctx        = context.Background()
		loginQuery = func(db *mockdb.MockDB) *gomock.Call {
			return db.EXPECT().QueryContext(
				ctx,
				mockutil.HasPrefix(selectQueryHead),
				gomock.AssignableToTypeOf(""),
			)
		}
		loginScan = func(rows *mockdb.MockRows) *gomock.Call {
			return rows.EXPECT().Scan(
				gomock.AssignableToTypeOf(intptr),
				gomock.AssignableToTypeOf(&uuid.UUID{}),
				gomock.AssignableToTypeOf(strptr),   // username
				gomock.AssignableToTypeOf(strptr),   // email
				gomock.AssignableToTypeOf(bytesptr), // password hash
				gomock.AssignableToTypeOf(strptr),   // totp key
				gomock.Any(),                        // roles
				gomock.AssignableToTypeOf(&time.Time{}),
				gomock.AssignableToTypeOf(&time.Time{}),
			)
		}
	)

	type table struct {
		cfg   auth.TokenConfig
		body  map[string]string
		errs  []error
		query url.Values
		prep  func(db *mockdb.MockDB, rows *mockdb.MockRows)
	}

	for i, tt := range []table{
		{
			cfg:  auth.GenEdDSATokenConfig(),
			body: nil,
			errs: []error{ErrEmptyPassword, echo.ErrNotFound},
		},
		{
			cfg:  auth.GenEdDSATokenConfig(),
			body: map[string]string{"password": "1234"},
			errs: []error{ErrUserNotFound, echo.ErrNotFound},
		},
		{
			cfg:  auth.GenerateECDSATokenConfig(),
			body: map[string]string{"email": "joe@joe.com", "password": "im the real joe"},
			errs: []error{sql.ErrConnDone, echo.ErrNotFound},
			prep: func(db *mockdb.MockDB, rows *mockdb.MockRows) {
				loginQuery(db).Return(rows, nil)
				rows.EXPECT().Next().Return(true)
				loginScan(rows).Return(sql.ErrConnDone)
				rows.EXPECT().Close().Return(nil)
			},
		},
		{
			cfg:  auth.GenerateECDSATokenConfig(),
			body: map[string]string{"email": "joe@joe.com", "password": "im the real joe"},
			errs: []error{ErrUserNotFound, echo.ErrNotFound},
			prep: func(db *mockdb.MockDB, rows *mockdb.MockRows) {
				loginQuery(db).Return(rows, nil)
				rows.EXPECT().Next().Return(false)
				rows.EXPECT().Err().Return(ErrUserNotFound)
				rows.EXPECT().Close().Return(nil)
			},
		},
		{
			cfg:  auth.GenerateECDSATokenConfig(),
			body: map[string]string{"email": "joe@joe.com", "password": "im the real joe"},
			errs: []error{sql.ErrNoRows, echo.ErrNotFound},
			prep: func(db *mockdb.MockDB, rows *mockdb.MockRows) {
				loginQuery(db).Return(rows, sql.ErrNoRows)
			},
		},
		{
			cfg:  auth.GenEdDSATokenConfig(),
			body: map[string]string{"username": "tester", "password": "asdfasdf"},
			errs: []error{sql.ErrNoRows, echo.ErrNotFound},
			prep: func(db *mockdb.MockDB, rows *mockdb.MockRows) {
				loginQuery(db).Times(1).Return(rows, nil)
				rows.EXPECT().Next().Return(false)
				rows.EXPECT().Err().Return(nil)
				rows.EXPECT().Close().Return(nil)
			},
		},
		{
			cfg:  auth.GenerateECDSATokenConfig(),
			body: map[string]string{"email": "joe@joe.com", "password": "im the real joe"},
			errs: []error{ErrWrongPassword, echo.ErrNotFound},
			prep: func(db *mockdb.MockDB, rows *mockdb.MockRows) {
				loginQuery(db).Return(rows, nil)
				rows.EXPECT().Next().Return(true)
				loginScan(rows).Return(nil)
				rows.EXPECT().Close().Return(nil)
			},
		},
		{
			cfg:   auth.GenerateECDSATokenConfig(),
			body:  map[string]string{"username": "tester", "password": "asdfasdf"},
			query: url.Values{"cookie": {"true"}},
			prep: func(db *mockdb.MockDB, rows *mockdb.MockRows) {
				loginQuery(db).Times(1).Return(rows, nil)
				rows.EXPECT().Next().Return(true)
				loginScan(rows).Times(1).Do(func(v ...interface{}) {
					pw := v[4].(*[]byte)
					var e error
					*pw, e = bcrypt.GenerateFromPassword([]byte("asdfasdf"), hashCost)
					if e != nil {
						t.Fatal(e)
					}
				}).Return(nil)
				rows.EXPECT().Close().Return(nil)
			},
		},
		{
			cfg:   auth.GenEdDSATokenConfig(),
			errs:  []error{echo.ErrBadRequest},
			query: url.Values{"cookie": {"notaboolean"}},
		},
	} {
		if tt.prep == nil {
			tt.prep = func(*mockdb.MockDB, *mockdb.MockRows) {}
		}
		t.Run(fmt.Sprintf("TestTokenHandler_%d", i), func(t *testing.T) {
			var (
				is   = is.New(t)
				e    = echo.New()
				ctrl = gomock.NewController(t)
				db   = mockdb.NewMockDB(ctrl)
				rows = mockdb.NewMockRows(ctrl)
				rec  = httptest.NewRecorder()
				req  = httptest.NewRequest("POST", "/", body(tt.body)).WithContext(ctx)
			)
			defer ctrl.Finish()
			req.Header.Set(echo.HeaderContentType, "application/json")
			req.URL.RawQuery = tt.query.Encode()

			handler := TokenHandler(tt.cfg, NewUserStore(db))
			tt.prep(db, rows)
			c := e.NewContext(req, rec)
			err := handler(c)
			checkErrs(t, tt.errs, err)

			if len(tt.errs) > 0 {
				return
			}

			resp := rec.Result()
			var (
				tok     *auth.TokenResponse
				cookies = resp.Cookies()
			)
			is.NoErr(json.NewDecoder(resp.Body).Decode(&tok))
			is.Equal(1, len(cookies))
			is.Equal("/", cookies[0].Path)
			is.Equal(cookies[0].Value, tok.Token)
			is.Equal(cookies[0].Expires, tok.Expires.Time.UTC())
			claims := auth.GetClaims(c)
			is.True(claims != nil)
		})
	}
}
func TestRefreshTokenHandler_Err(t *testing.T) {
	type table struct {
		prep func(claims *auth.Claims, v url.Values)
	}
	for i, tt := range []table{
		{prep: func(claims *auth.Claims, v url.Values) { claims.Audience = []string{"not correct aud"} }},
		{prep: func(claims *auth.Claims, v url.Values) {
			n := time.Now()
			claims.ExpiresAt = jwt.NewNumericDate(time.Date(
				n.Year(), n.Month(), n.Day(), n.Hour()-5,
				n.Minute(), n.Second(), n.Nanosecond(), n.Location(),
			))
		}},
		{prep: func(claims *auth.Claims, v url.Values) {
			claims.ID = claims.ID + 1
		}},
		{prep: func(claims *auth.Claims, v url.Values) {
			claims.UUID[0] = 'h'
			claims.UUID[1] = 'e'
			claims.UUID[2] = 'l'
			claims.UUID[3] = 'l'
			claims.UUID[4] = 'o'
		}},
		{prep: func(claims *auth.Claims, v url.Values) {
			v.Add("cookie", "not-a-boolean")
		}},
	} {
		t.Run(fmt.Sprintf("%s_%d", t.Name(), i), func(t *testing.T) {
			is := is.New(t)
			tokenCfg := auth.GenEdDSATokenConfig()
			claims := &auth.Claims{
				ID:   mathrand.Int(),
				UUID: uuid.New(),
				RegisteredClaims: jwt.RegisteredClaims{
					IssuedAt:  jwt.NewNumericDate(time.Now()),
					ExpiresAt: jwt.NewNumericDate(time.Now().Add(auth.Expiration)),
					Audience:  []string{"refresh"},
					Issuer:    auth.Issuer,
				},
			}
			params := url.Values{}
			userClaims := *claims
			userClaims.Audience = []string{auth.TokenAudience}
			if tt.prep != nil {
				tt.prep(claims, params)
			}
			refreshToken, err := jwt.NewWithClaims(tokenCfg.Type(), claims).SignedString(tokenCfg.Private())
			is.NoErr(err)
			e := echo.New()
			rec := httptest.NewRecorder()
			req := httptest.NewRequest("POST", "/api/refresh", body(map[string]string{"refresh_token": refreshToken}))
			req.URL.RawQuery = params.Encode()
			req.Header.Set("Content-Type", "application/json")
			c := e.NewContext(req, rec)
			c.Set(auth.ClaimsContextKey, &userClaims)
			handler := RefreshTokenHandler(tokenCfg)
			err = handler(c)
			if err == nil {
				t.Fatal("expected an error got nil")
			}
		})
	}
}

func TestRefreshTokenHandler(t *testing.T) {
	is := is.New(t)
	tokenCfg := auth.GenEdDSATokenConfig()
	claims := &auth.Claims{
		ID:   mathrand.Int(),
		UUID: uuid.New(),
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(auth.Expiration)),
			Audience:  []string{"refresh"},
			Issuer:    auth.Issuer,
		},
	}
	refreshToken, err := jwt.NewWithClaims(tokenCfg.Type(), claims).SignedString(tokenCfg.Private())
	is.NoErr(err)
	e := echo.New()
	req := httptest.NewRequest(
		"POST", "/api/refresh?cookie=true",
		body(map[string]string{"refresh_token": refreshToken}),
	)
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)
	c.Set(auth.ClaimsContextKey, claims)
	handler := RefreshTokenHandler(tokenCfg)
	err = handler(c)
	is.NoErr(err)
	res := rec.Result()
	is.Equal(res.StatusCode, 200)
	is.Equal(1, len(res.Cookies()))
	cookie := res.Cookies()[0]
	is.Equal(cookie.Name, tokenKey)
	is.Equal(cookie.Path, "/")
}

func TestLogList(t *testing.T) {
	var (
		ctx = context.Background()
	)
	type table struct {
		errs  []error
		query url.Values
		prep  func(db *mockdb.MockDB, rows *mockdb.MockRows)
	}
	expectScan := func(rows *mockdb.MockRows) *gomock.Call {
		return rows.EXPECT().Scan(
			gomock.AssignableToTypeOf(intptr),
			gomock.AssignableToTypeOf(strptr),
			gomock.AssignableToTypeOf(intptr),
			gomock.AssignableToTypeOf(strptr),
			gomock.AssignableToTypeOf(strptr),
			gomock.AssignableToTypeOf(&sql.NullString{}),
			gomock.AssignableToTypeOf(strptr),
			gomock.AssignableToTypeOf(durationPtr),
			gomock.Any(),
			gomock.AssignableToTypeOf(&time.Time{}),
		)
	}

	for i, tt := range []table{
		{
			errs:  []error{},
			query: url.Values{"limit": {"12"}, "offset": {"0"}},
			prep: func(db *mockdb.MockDB, rows *mockdb.MockRows) {
				db.EXPECT().QueryContext(ctx, getLogsQuery+" LIMIT $2", []interface{}{0, 12}).Return(rows, nil)
				rows.EXPECT().Next().Times(1).Return(true)
				expectScan(rows).Do(func(v ...interface{}) {}).Return(nil)
				rows.EXPECT().Next().Times(1).Return(false)
				rows.EXPECT().Close().Return(nil)
			},
		},
	} {
		if tt.prep == nil {
			tt.prep = func(*mockdb.MockDB, *mockdb.MockRows) {}
		}
		t.Run(fmt.Sprintf("%s_%d", t.Name(), i), func(t *testing.T) {
			ctrl := gomock.NewController(t)
			defer ctrl.Finish()
			db := mockdb.NewMockDB(ctrl)
			rows := mockdb.NewMockRows(ctrl)
			e := echo.New()
			rec := httptest.NewRecorder()
			req := httptest.NewRequest("GET", "/", nil).WithContext(ctx)
			req.URL.RawQuery = tt.query.Encode()
			handler := LogListHandler(db)
			c := e.NewContext(req, rec)
			tt.prep(db, rows)
			err := handler(c)
			checkErrs(t, tt.errs, err)
			if len(tt.errs) > 0 {
				return
			}
		})
	}
}

func checkErrs(t *testing.T, expected []error, err error) (stop bool) {
	t.Helper()
	if len(expected) > 0 {
		for _, er := range expected {
			if !errors.Is(err, er) {
				t.Errorf("expected \"%v\", got \"%v\"", er, err)
			}
		}
		return true
	} else {
		if err != nil {
			t.Error(err)
		}
	}
	return false
}

func silent() func() {
	out := logger.Out
	logger.SetOutput(io.Discard)
	return func() { logger.SetOutput(out) }
}

func body(m map[string]string) io.Reader {
	var b bytes.Buffer
	if err := json.NewEncoder(&b).Encode(m); err != nil {
		panic(err)
	}
	return &b
}