//! Shadow backend library surface.
//!
//! `main.rs` remains the entry point for the `shadow-backend` binary. This
//! library target exposes the self-contained utility modules (validation,
//! rate limiting, caching) so that integration tests under `backend/tests/`
//! can reference them via `use shadow_backend::...`.
//!
//! Only modules that do not depend on binary-only wiring (web server,
//! handlers, database setup) are re-exported here.

pub mod apollo;
pub mod artemis;
pub mod db;
pub mod hephaestus;
