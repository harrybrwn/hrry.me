use std::fmt;

use actix_web::ResponseError;

use crate::dao;

#[derive(Debug)]
pub enum Error {
    Dao(dao::Error),
    Any(anyhow::Error),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Dao(e) => e.fmt(f),
            Self::Any(e) => e.fmt(f),
        }
    }
}

impl ResponseError for Error {
    fn status_code(&self) -> actix_web::http::StatusCode {
        match self {
            Self::Dao(e) => e.status_code(),
            Self::Any(_) => actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
        }
    }
    // TODO implement error_response for custom error logging
}

impl From<dao::Error> for Error {
    fn from(value: dao::Error) -> Self {
        Self::Dao(value)
    }
}

impl From<anyhow::Error> for Error {
    fn from(value: anyhow::Error) -> Self {
        Self::Any(value)
    }
}
