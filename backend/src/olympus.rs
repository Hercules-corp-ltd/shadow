// Olympus - The Pantheon of Gods (CA Domain System)
// Handles domain registration, verification, and management for Shadow sites

use mongodb::{Collection, Database};
use mongodb::bson::doc;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Domain {
    #[serde(rename = "_id")]
    pub domain: String,                    // e.g., "example.shadow"
    pub owner_pubkey: String,              // Wallet that owns the domain
    pub program_address: String,           // Solana program address it points to
    pub verified: bool,                    // Whether domain is verified on-chain
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub expires_at: Option<DateTime<Utc>>, // Optional expiration
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DomainRegistration {
    pub domain: String,
    pub program_address: String,
    pub owner_pubkey: String,
}

pub struct OlympusCA {
    db: Database,
}

impl OlympusCA {
    pub fn new(db: Database) -> Self {
        Self { db }
    }

    fn get_domains_collection(&self) -> Collection<Domain> {
        self.db.collection::<Domain>("domains")
    }

    /// Register a new domain (Pantheon entry)
    /// Maps a domain to a Solana program/contract address
    pub async fn register_domain(
        &self,
        domain: &str,
        owner_pubkey: &str,
        program_address: &str,
    ) -> Result<(), String> {
        // Domain validation is done by Apollo, just check it's not empty
        if domain.is_empty() {
            return Err("Domain cannot be empty".to_string());
        }

        let collection = self.get_domains_collection();
        let now = Utc::now();
        let bson_now = mongodb::bson::DateTime::from_millis(now.timestamp_millis());

        let filter = doc! { "_id": domain };
        let update = doc! {
            "$set": {
                "owner_pubkey": owner_pubkey,
                "program_address": program_address,
                "verified": false,
                "updated_at": bson_now
            },
            "$setOnInsert": {
                "created_at": bson_now
            }
        };

        let options = mongodb::options::UpdateOptions::builder()
            .upsert(true)
            .build();

        collection.update_one(filter, update, options).await
            .map_err(|e| format!("Database error: {}", e))?;

        Ok(())
    }

    /// Get domain by name
    pub async fn get_domain(&self, domain: &str) -> Result<Option<Domain>, String> {
        let collection = self.get_domains_collection();
        let filter = doc! { "_id": domain };
        
        collection.find_one(filter, None).await
            .map_err(|e| format!("Database error: {}", e))
    }

    /// Get domain by program address
    pub async fn get_domain_by_program(&self, program_address: &str) -> Result<Option<Domain>, String> {
        let collection = self.get_domains_collection();
        let filter = doc! { "program_address": program_address };
        
        collection.find_one(filter, None).await
            .map_err(|e| format!("Database error: {}", e))
    }

    /// Verify domain ownership (mark as verified after on-chain verification)
    pub async fn verify_domain(&self, domain: &str) -> Result<(), String> {
        let collection = self.get_domains_collection();
        let now = Utc::now();
        let bson_now = mongodb::bson::DateTime::from_millis(now.timestamp_millis());

        let filter = doc! { "_id": domain };
        let update = doc! {
            "$set": {
                "verified": true,
                "updated_at": bson_now
            }
        };

        collection.update_one(filter, update, None).await
            .map_err(|e| format!("Database error: {}", e))?;

        Ok(())
    }

    /// Transfer domain ownership
    pub async fn transfer_domain(
        &self,
        domain: &str,
        new_owner: &str,
    ) -> Result<(), String> {
        let collection = self.get_domains_collection();
        let now = Utc::now();
        let bson_now = mongodb::bson::DateTime::from_millis(now.timestamp_millis());

        let filter = doc! { "_id": domain };
        let update = doc! {
            "$set": {
                "owner_pubkey": new_owner,
                "verified": false, // Require re-verification after transfer
                "updated_at": bson_now
            }
        };

        collection.update_one(filter, update, None).await
            .map_err(|e| format!("Database error: {}", e))?;

        Ok(())
    }

    /// List domains owned by a wallet
    pub async fn list_owner_domains(&self, owner_pubkey: &str) -> Result<Vec<Domain>, String> {
        let collection = self.get_domains_collection();
        let filter = doc! { "owner_pubkey": owner_pubkey };
        
        let mut cursor = collection.find(filter, None).await
            .map_err(|e| format!("Database error: {}", e))?;

        let mut domains = Vec::new();
        use futures_util::TryStreamExt;
        while let Some(domain) = cursor.try_next().await
            .map_err(|e| format!("Database error: {}", e))? {
            domains.push(domain);
        }

        Ok(domains)
    }

    /// Search domains
    pub async fn search_domains(&self, query: &str, limit: i64) -> Result<Vec<Domain>, String> {
        let collection = self.get_domains_collection();
        let filter = doc! {
            "$or": [
                { "_id": { "$regex": query, "$options": "i" } },
                { "program_address": { "$regex": query, "$options": "i" } }
            ],
            "verified": true
        };

        let options = mongodb::options::FindOptions::builder()
            .limit(limit)
            .sort(doc! { "created_at": -1 })
            .build();

        let mut cursor = collection.find(filter, options).await
            .map_err(|e| format!("Database error: {}", e))?;

        let mut domains = Vec::new();
        use futures_util::TryStreamExt;
        while let Some(domain) = cursor.try_next().await
            .map_err(|e| format!("Database error: {}", e))? {
            domains.push(domain);
        }

        Ok(domains)
    }
}

