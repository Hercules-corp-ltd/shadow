use actix_web::{HttpResponse, ResponseError};
use std::fmt;

#[derive(Debug)]
pub enum ShadowError {
    Database(mongodb::error::Error),
    Storage(String),
    Solana(String),
    NotFound(String),
    BadRequest(String),
    Unauthorized,
}

impl fmt::Display for ShadowError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ShadowError::Database(e) => write!(f, "Database error: {}", e),
            ShadowError::Storage(e) => write!(f, "Storage error: {}", e),
            ShadowError::Solana(e) => write!(f, "Solana error: {}", e),
            ShadowError::NotFound(e) => write!(f, "Not found: {}", e),
            ShadowError::BadRequest(e) => write!(f, "Bad request: {}", e),
            ShadowError::Unauthorized => write!(f, "Unauthorized"),
        }
    }
}

impl ResponseError for ShadowError {
    fn error_response(&self) -> HttpResponse {
        match self {
            ShadowError::Database(_) => {
                HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Database error"
                }))
            }
            ShadowError::Storage(_) => {
                HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Storage error"
                }))
            }
            ShadowError::Solana(_) => {
                HttpResponse::InternalServerError().json(serde_json::json!({
                    "error": "Solana error"
                }))
            }
            ShadowError::NotFound(msg) => {
                HttpResponse::NotFound().json(serde_json::json!({
                    "error": msg
                }))
            }
            ShadowError::BadRequest(msg) => {
                HttpResponse::BadRequest().json(serde_json::json!({
                    "error": msg
                }))
            }
            ShadowError::Unauthorized => {
                HttpResponse::Unauthorized().json(serde_json::json!({
                    "error": "Unauthorized"
                }))
            }
        }
    }
}

impl From<mongodb::error::Error> for ShadowError {
    fn from(err: mongodb::error::Error) -> Self {
        ShadowError::Database(err)
    }
}

impl From<String> for ShadowError {
    fn from(err: String) -> Self {
        ShadowError::BadRequest(err)
    }
}

