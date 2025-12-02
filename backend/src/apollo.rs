// Apollo - God of Truth and Light
// Handles input validation, sanitization, and truth verification

use solana_sdk::pubkey::Pubkey;
use std::str::FromStr;

pub struct ApolloValidator;

impl ApolloValidator {
    pub fn new() -> Self {
        Self
    }

    /// Validate Solana wallet address (pubkey)
    pub fn validate_pubkey(pubkey: &str) -> Result<Pubkey, String> {
        Pubkey::from_str(pubkey)
            .map_err(|e| format!("Invalid Solana pubkey: {}", e))
    }

    /// Validate domain name format
    /// Supports both .shadow domains and custom domains
    pub fn validate_domain(domain: &str) -> Result<(), String> {
        // Check if it's a .shadow domain
        if domain.ends_with(".shadow") {
            let domain_name = domain.strip_suffix(".shadow").unwrap();
            
            if domain_name.is_empty() {
                return Err("Domain name cannot be empty".to_string());
            }

            if domain_name.len() > 63 {
                return Err("Domain name too long (max 63 characters)".to_string());
            }

            if !domain_name.chars().all(|c| c.is_alphanumeric() || c == '-') {
                return Err("Domain name can only contain alphanumeric characters and hyphens".to_string());
            }

            if domain_name.starts_with('-') || domain_name.ends_with('-') {
                return Err("Domain name cannot start or end with a hyphen".to_string());
            }
        } else {
            // Custom domain validation (more permissive)
            if domain.is_empty() {
                return Err("Domain cannot be empty".to_string());
            }

            if domain.len() > 253 {
                return Err("Domain too long (max 253 characters)".to_string());
            }

            // Basic domain format validation
            let parts: Vec<&str> = domain.split('.').collect();
            if parts.len() < 2 {
                return Err("Domain must have at least a TLD".to_string());
            }

            for part in &parts {
                if part.is_empty() {
                    return Err("Domain parts cannot be empty".to_string());
                }
                if part.len() > 63 {
                    return Err("Domain part too long (max 63 characters)".to_string());
                }
            }
        }

        Ok(())
    }

    /// Validate IPFS CID format (basic check)
    pub fn validate_ipfs_cid(cid: &str) -> Result<(), String> {
        if cid.starts_with("ipfs://") {
            let hash = cid.strip_prefix("ipfs://").unwrap();
            if hash.is_empty() {
                return Err("IPFS CID cannot be empty".to_string());
            }
            // Basic validation - IPFS CIDs are base58 encoded
            if hash.len() < 10 || hash.len() > 100 {
                return Err("Invalid IPFS CID length".to_string());
            }
        } else if !cid.is_empty() {
            // Allow non-prefixed CIDs
            if cid.len() < 10 || cid.len() > 100 {
                return Err("Invalid IPFS CID length".to_string());
            }
        }

        Ok(())
    }

    /// Validate Arweave transaction ID format
    pub fn validate_arweave_tx(tx_id: &str) -> Result<(), String> {
        if tx_id.starts_with("arweave://") {
            let id = tx_id.strip_prefix("arweave://").unwrap();
            if id.is_empty() {
                return Err("Arweave transaction ID cannot be empty".to_string());
            }
            // Arweave TX IDs are base64url encoded, typically 43 characters
            if id.len() < 20 || id.len() > 100 {
                return Err("Invalid Arweave transaction ID length".to_string());
            }
        } else if !tx_id.is_empty() {
            if tx_id.len() < 20 || tx_id.len() > 100 {
                return Err("Invalid Arweave transaction ID length".to_string());
            }
        }

        Ok(())
    }

    /// Sanitize string input (remove dangerous characters)
    pub fn sanitize_string(input: &str, max_length: usize) -> Result<String, String> {
        if input.len() > max_length {
            return Err(format!("String too long (max {} characters)", max_length));
        }

        // Remove null bytes and control characters
        let sanitized: String = input
            .chars()
            .filter(|c| !c.is_control() || *c == '\n' || *c == '\r' || *c == '\t')
            .collect();

        Ok(sanitized)
    }

    /// Validate search query
    pub fn validate_search_query(query: &str) -> Result<(), String> {
        if query.is_empty() {
            return Err("Search query cannot be empty".to_string());
        }

        if query.len() > 200 {
            return Err("Search query too long (max 200 characters)".to_string());
        }

        Ok(())
    }

    /// Validate limit parameter
    pub fn validate_limit(limit: Option<i64>) -> Result<i64, String> {
        let limit = limit.unwrap_or(10);
        
        if limit < 1 {
            return Err("Limit must be at least 1".to_string());
        }

        if limit > 100 {
            return Err("Limit cannot exceed 100".to_string());
        }

        Ok(limit)
    }
}

impl Default for ApolloValidator {
    fn default() -> Self {
        Self::new()
    }
}

