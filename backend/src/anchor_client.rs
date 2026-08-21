// Anchor client for on-chain program verification
// Verifies registry and profiles program accounts

use solana_client::rpc_client::RpcClient;
use solana_sdk::pubkey::Pubkey;
use std::str::FromStr;

// Program IDs (must be valid base58 32-byte pubkeys — the previous placeholders
// contained `0` and were too short, so Pubkey::from_str failed at process start).
// Override with SHADOW_REGISTRY_PROGRAM_ID / SHADOW_PROFILES_PROGRAM_ID after a
// real deploy (`anchor keys list`).
const REGISTRY_PROGRAM_ID: &str = "8Mc4gjS1y6SZUGQGydtqoHAsjRwCmeux1KjKFYDKqTtu";
const PROFILES_PROGRAM_ID: &str = "55VcSJ49rjAqYjxxFKwX9w6tzRUGLgMofGGD9mAGPkff";

pub struct AnchorClient {
    rpc_url: String,
    registry_program: Pubkey,
    profiles_program: Pubkey,
}

#[derive(Debug, Clone)]
pub struct SiteAccount {
    pub owner: Pubkey,
    pub program_address: Pubkey,
    pub name: String,
    pub description: String,
    pub storage_cid: String,
    pub created_at: i64,
    pub updated_at: i64,
}

#[derive(Debug, Clone)]
pub struct ProfileAccount {
    pub wallet: Pubkey,
    pub profile_cid: String,
    pub is_public: bool,
    pub created_at: i64,
    pub updated_at: i64,
}

impl AnchorClient {
    pub fn new(rpc_url: String) -> Result<Self, String> {
        let registry_id = std::env::var("SHADOW_REGISTRY_PROGRAM_ID")
            .unwrap_or_else(|_| REGISTRY_PROGRAM_ID.to_string());
        let profiles_id = std::env::var("SHADOW_PROFILES_PROGRAM_ID")
            .unwrap_or_else(|_| PROFILES_PROGRAM_ID.to_string());

        let registry_program = Pubkey::from_str(&registry_id)
            .map_err(|e| format!("Invalid registry program ID: {}", e))?;
        
        let profiles_program = Pubkey::from_str(&profiles_id)
            .map_err(|e| format!("Invalid profiles program ID: {}", e))?;

        Ok(Self {
            rpc_url,
            registry_program,
            profiles_program,
        })
    }

    /// Verify a site is registered on-chain
    pub fn verify_site_registration(
        &self,
        program_address: &str,
        owner_pubkey: &str,
    ) -> Result<Option<SiteAccount>, String> {
        let program = Pubkey::from_str(program_address)
            .map_err(|e| format!("Invalid program pubkey: {}", e))?;
        
        let owner = Pubkey::from_str(owner_pubkey)
            .map_err(|e| format!("Invalid owner pubkey: {}", e))?;

        let client = RpcClient::new(&self.rpc_url);
        
        // Derive site PDA: findProgramAddress(["site", program_address])
        // For now, we'll use a simplified approach
        // In production, use anchor_lang::prelude::Pubkey::find_program_address
        
        // Get account data
        // This is a placeholder - in production, you'd:
        // 1. Derive the PDA using the seeds ["site", program_address]
        // 2. Fetch the account
        // 3. Deserialize using Anchor's AccountDeserialize
        
        // Simplified check: verify program exists and is owned by registry
        match client.get_account(&program) {
            Ok(account) if account.owner == self.registry_program => {
                // Account exists and is owned by registry program
                // In production, deserialize the account data here
                Ok(Some(SiteAccount {
                    owner,
                    program_address: program,
                    name: String::new(), // Would be deserialized from account data
                    description: String::new(),
                    storage_cid: String::new(),
                    created_at: 0,
                    updated_at: 0,
                }))
            }
            _ => Ok(None),
        }
    }

    /// Verify a profile exists on-chain
    pub fn verify_profile(
        &self,
        wallet: &str,
    ) -> Result<Option<ProfileAccount>, String> {
        let _wallet_pubkey = Pubkey::from_str(wallet)
            .map_err(|e| format!("Invalid wallet pubkey: {}", e))?;

        let _client = RpcClient::new(&self.rpc_url);
        
        // Derive profile PDA: findProgramAddress(["profile", wallet])
        // For now, simplified approach
        
        // In production:
        // 1. Derive PDA using seeds ["profile", wallet]
        // 2. Fetch account
        // 3. Deserialize using Anchor's AccountDeserialize
        
        // Simplified: check if any account owned by profiles program exists
        // This is a placeholder - full implementation would derive and fetch the PDA
        Ok(None)
    }

    /// Get registry program ID
    pub fn registry_program_id(&self) -> &Pubkey {
        &self.registry_program
    }

    /// Get profiles program ID
    pub fn profiles_program_id(&self) -> &Pubkey {
        &self.profiles_program
    }
}

