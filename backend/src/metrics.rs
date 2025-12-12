// Metrics collection for Shadow backend
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackendMetrics {
    pub total_requests: u64,
    pub successful_requests: u64,
    pub failed_requests: u64,
    pub average_response_time_ms: f64,
    pub cache_hits: u64,
    pub cache_misses: u64,
    pub database_queries: u64,
    pub solana_rpc_calls: u64,
}

pub struct MetricsCollector {
    total_requests: Arc<AtomicU64>,
    successful_requests: Arc<AtomicU64>,
    failed_requests: Arc<AtomicU64>,
    response_times: Arc<dashmap::DashMap<String, Vec<u64>>>,
    cache_hits: Arc<AtomicU64>,
    cache_misses: Arc<AtomicU64>,
    database_queries: Arc<AtomicU64>,
    solana_rpc_calls: Arc<AtomicU64>,
}

impl MetricsCollector {
    pub fn new() -> Self {
        Self {
            total_requests: Arc::new(AtomicU64::new(0)),
            successful_requests: Arc::new(AtomicU64::new(0)),
            failed_requests: Arc::new(AtomicU64::new(0)),
            response_times: Arc::new(dashmap::DashMap::new()),
            cache_hits: Arc::new(AtomicU64::new(0)),
            cache_misses: Arc::new(AtomicU64::new(0)),
            database_queries: Arc::new(AtomicU64::new(0)),
            solana_rpc_calls: Arc::new(AtomicU64::new(0)),
        }
    }
    
    pub fn record_request(&self, success: bool, response_time_ms: u64, endpoint: &str) {
        self.total_requests.fetch_add(1, Ordering::Relaxed);
        
        if success {
            self.successful_requests.fetch_add(1, Ordering::Relaxed);
        } else {
            self.failed_requests.fetch_add(1, Ordering::Relaxed);
        }
        
        let mut times = self.response_times.entry(endpoint.to_string())
            .or_insert_with(Vec::new);
        times.push(response_time_ms);
        
        // Keep only last 1000 measurements per endpoint
        if times.len() > 1000 {
            times.remove(0);
        }
    }
    
    pub fn record_cache_hit(&self) {
        self.cache_hits.fetch_add(1, Ordering::Relaxed);
    }
    
    pub fn record_cache_miss(&self) {
        self.cache_misses.fetch_add(1, Ordering::Relaxed);
    }
    
    pub fn record_database_query(&self) {
        self.database_queries.fetch_add(1, Ordering::Relaxed);
    }
    
    pub fn record_solana_rpc(&self) {
        self.solana_rpc_calls.fetch_add(1, Ordering::Relaxed);
    }
    
    pub fn get_metrics(&self) -> BackendMetrics {
        let total = self.total_requests.load(Ordering::Relaxed);
        let successful = self.successful_requests.load(Ordering::Relaxed);
        let failed = self.failed_requests.load(Ordering::Relaxed);
        
        // Calculate average response time
        let mut total_time = 0u64;
        let mut count = 0u64;
        for times in self.response_times.iter() {
            total_time += times.value().iter().sum::<u64>();
            count += times.value().len() as u64;
        }
        let avg_time = if count > 0 {
            total_time as f64 / count as f64
        } else {
            0.0
        };
        
        BackendMetrics {
            total_requests: total,
            successful_requests: successful,
            failed_requests: failed,
            average_response_time_ms: avg_time,
            cache_hits: self.cache_hits.load(Ordering::Relaxed),
            cache_misses: self.cache_misses.load(Ordering::Relaxed),
            database_queries: self.database_queries.load(Ordering::Relaxed),
            solana_rpc_calls: self.solana_rpc_calls.load(Ordering::Relaxed),
        }
    }
    
    pub fn reset(&self) {
        self.total_requests.store(0, Ordering::Relaxed);
        self.successful_requests.store(0, Ordering::Relaxed);
        self.failed_requests.store(0, Ordering::Relaxed);
        self.response_times.clear();
        self.cache_hits.store(0, Ordering::Relaxed);
        self.cache_misses.store(0, Ordering::Relaxed);
        self.database_queries.store(0, Ordering::Relaxed);
        self.solana_rpc_calls.store(0, Ordering::Relaxed);
    }
}

impl Default for MetricsCollector {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_metrics_collection() {
        let metrics = MetricsCollector::new();
        
        metrics.record_request(true, 100, "/api/test");
        metrics.record_request(false, 200, "/api/test");
        metrics.record_cache_hit();
        metrics.record_cache_miss();
        metrics.record_database_query();
        metrics.record_solana_rpc();
        
        let result = metrics.get_metrics();
        assert_eq!(result.total_requests, 2);
        assert_eq!(result.successful_requests, 1);
        assert_eq!(result.failed_requests, 1);
        assert_eq!(result.cache_hits, 1);
        assert_eq!(result.cache_misses, 1);
        assert_eq!(result.database_queries, 1);
        assert_eq!(result.solana_rpc_calls, 1);
    }
}


