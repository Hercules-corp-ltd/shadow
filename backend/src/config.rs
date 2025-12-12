// Configuration management for Shadow backend
use serde::{Deserialize, Serialize};
use std::env;
use std::time::Duration;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseConfig {
    pub url: String,
    pub database_name: String,
    pub max_pool_size: Option<u32>,
    pub min_pool_size: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SolanaConfig {
    pub rpc_url: String,
    pub ws_url: String,
    pub commitment: String,
    pub timeout_seconds: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageConfig {
    pub pinata_api_key: Option<String>,
    pub pinata_secret_key: Option<String>,
    pub bundlr_node_url: Option<String>,
    pub bundlr_currency: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheConfig {
    pub max_size_mb: usize,
    pub default_ttl_seconds: u64,
    pub cleanup_interval_seconds: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RateLimitConfig {
    pub requests_per_minute: u32,
    pub burst_size: Option<u32>,
    pub enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub workers: Option<usize>,
    pub keep_alive: Option<u64>,
    pub client_timeout: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ShadowConfig {
    pub database: DatabaseConfig,
    pub solana: SolanaConfig,
    pub storage: StorageConfig,
    pub cache: CacheConfig,
    pub rate_limit: RateLimitConfig,
    pub server: ServerConfig,
}

impl ShadowConfig {
    pub fn from_env() -> Result<Self, String> {
        Ok(ShadowConfig {
            database: DatabaseConfig {
                url: env::var("DATABASE_URL")
                    .map_err(|_| "DATABASE_URL not set")?,
                database_name: env::var("DATABASE_NAME")
                    .unwrap_or_else(|_| "shadow".to_string()),
                max_pool_size: env::var("DATABASE_MAX_POOL_SIZE")
                    .ok()
                    .and_then(|s| s.parse().ok()),
                min_pool_size: env::var("DATABASE_MIN_POOL_SIZE")
                    .ok()
                    .and_then(|s| s.parse().ok()),
            },
            solana: SolanaConfig {
                rpc_url: env::var("SOLANA_RPC_URL")
                    .unwrap_or_else(|_| "https://api.devnet.solana.com".to_string()),
                ws_url: env::var("SOLANA_WS_URL")
                    .unwrap_or_else(|_| "wss://api.devnet.solana.com".to_string()),
                commitment: env::var("SOLANA_COMMITMENT")
                    .unwrap_or_else(|_| "confirmed".to_string()),
                timeout_seconds: env::var("SOLANA_TIMEOUT_SECONDS")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(30),
            },
            storage: StorageConfig {
                pinata_api_key: env::var("PINATA_API_KEY").ok(),
                pinata_secret_key: env::var("PINATA_SECRET_KEY").ok(),
                bundlr_node_url: env::var("BUNDLR_NODE_URL").ok(),
                bundlr_currency: env::var("BUNDLR_CURRENCY")
                    .ok()
                    .or_else(|| Some("solana".to_string())),
            },
            cache: CacheConfig {
                max_size_mb: env::var("CACHE_MAX_SIZE_MB")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(512),
                default_ttl_seconds: env::var("CACHE_DEFAULT_TTL_SECONDS")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(3600),
                cleanup_interval_seconds: env::var("CACHE_CLEANUP_INTERVAL_SECONDS")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(300),
            },
            rate_limit: RateLimitConfig {
                requests_per_minute: env::var("RATE_LIMIT_RPM")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(60),
                burst_size: env::var("RATE_LIMIT_BURST")
                    .ok()
                    .and_then(|s| s.parse().ok()),
                enabled: env::var("RATE_LIMIT_ENABLED")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(true),
            },
            server: ServerConfig {
                host: env::var("HOST")
                    .unwrap_or_else(|_| "0.0.0.0".to_string()),
                port: env::var("PORT")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(8080),
                workers: env::var("WORKERS")
                    .ok()
                    .and_then(|s| s.parse().ok()),
                keep_alive: env::var("KEEP_ALIVE")
                    .ok()
                    .and_then(|s| s.parse().ok()),
                client_timeout: env::var("CLIENT_TIMEOUT")
                    .ok()
                    .and_then(|s| s.parse().ok()),
            },
        })
    }
    
    pub fn get_cache_ttl(&self) -> Duration {
        Duration::from_secs(self.cache.default_ttl_seconds)
    }
    
    pub fn get_solana_timeout(&self) -> Duration {
        Duration::from_secs(self.solana.timeout_seconds)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_config_defaults() {
        env::set_var("DATABASE_URL", "mongodb://localhost:27017");
        let config = ShadowConfig::from_env();
        assert!(config.is_ok());
        
        let cfg = config.unwrap();
        assert_eq!(cfg.server.port, 8080);
        assert_eq!(cfg.cache.max_size_mb, 512);
        assert_eq!(cfg.rate_limit.requests_per_minute, 60);
    }
}


