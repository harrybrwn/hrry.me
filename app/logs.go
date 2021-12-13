package app

import (
	"database/sql"
	"net"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/sirupsen/logrus"
)

type RequestLog struct {
	ID          int
	Method      string
	Status      int
	IP          string
	URI         string
	UserAgent   string
	Latency     time.Duration
	Error       error
	RequestedAt time.Time
}

const insertLogQuery = `
INSERT INTO request_log
	(method, status, ip, uri, user_agent, latency, error)
VALUES
	($1, $2, $3, $4, $5, $6, $7)`

func RecordRequest(db *sql.DB, l *RequestLog) error {
	var errmsg string
	if l.Error != nil {
		errmsg = l.Error.Error()
	}
	_, err := db.Exec(
		insertLogQuery,
		l.Method,
		l.Status,
		l.IP,
		l.URI,
		l.UserAgent,
		l.Latency,
		errmsg,
	)
	return err
}

func LogRequest(logger logrus.FieldLogger, l *RequestLog) {
	fields := logrus.Fields{
		"method":     l.Method,
		"status":     l.Status,
		"ip":         l.IP,
		"uri":        l.URI,
		"user_agent": l.UserAgent,
		"latency":    l.Latency,
	}
	if l.Error != nil {
		fields["error"] = l.Error
		logger.WithFields(fields).Error("request")
	} else {
		logger.WithFields(fields).Info("request")
	}
}

func RequestLogRecorder(db *sql.DB, logger logrus.FieldLogger) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			start := time.Now()
			req := c.Request()
			res := c.Response()
			ip, _, _ := net.SplitHostPort(req.RemoteAddr)
			err := next(c)
			l := RequestLog{
				Method:    req.Method,
				Status:    res.Status,
				IP:        ip,
				URI:       req.RequestURI,
				UserAgent: req.Header.Get("User-Agent"),
				Latency:   time.Since(start),
				Error:     err,
			}
			LogRequest(logger, &l)
			e := RecordRequest(db, &l)
			if e != nil {
				logger.WithError(e).Error("could not record request")
			}
			if err != nil {
				return err
			}
			return e
		}
	}
}