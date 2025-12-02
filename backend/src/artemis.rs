// Artemis - Goddess of the Hunt
// Handles rate limiting and request throttling

use dashmap::DashMap;
use std::time::{Duration, Instant};
use std::sync::Arc;

#[derive(Clone)]
struct RateLimitEntry {
    count: u32,
    reset_at: Instant,
}

pub struct ArtemisRateLimiter {
    requests_per_minute: u32,
    window_seconds: u64,
    store: Arc<DashMap<String, RateLimitEntry>>,
}

impl ArtemisRateLimiter {
    pub fn new(requests_per_minute: u32) -> Self {
        Self {
            requests_per_minute,
            window_seconds: 60,
            store: Arc::new(DashMap::new()),
        }
    }

    /// Check if a request should be allowed
    pub fn check_rate_limit(&self, key: &str) -> Result<(), String> {
        let now = Instant::now();
        
        // Clean up old entries periodically
        if self.store.len() > 10000 {
            self.store.retain(|_, entry| entry.reset_at > now);
        }

        let mut entry = self.store.entry(key.to_string()).or_insert_with(|| {
            RateLimitEntry {
                count: 0,
                reset_at: now + Duration::from_secs(self.window_seconds),
            }
        });

        // Reset if window expired
        if entry.reset_at < now {
            entry.count = 0;
            entry.reset_at = now + Duration::from_secs(self.window_seconds);
        }

        // Check limit
        if entry.count >= self.requests_per_minute {
            let remaining = entry.reset_at.duration_since(now).as_secs();
            return Err(format!("Rate limit exceeded. Try again in {} seconds", remaining));
        }

        entry.count += 1;
        Ok(())
    }

    /// Get client identifier from IP or wallet
    pub fn get_client_key(ip: Option<&str>, wallet: Option<&str>) -> String {
        if let Some(w) = wallet {
            format!("wallet:{}", w)
        } else if let Some(ip_addr) = ip {
            format!("ip:{}", ip_addr)
        } else {
            "unknown".to_string()
        }
    }
}

