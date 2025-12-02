// Ares - God of War and Security
// Handles wallet signature verification and authentication

use solana_sdk::signature::Signature;
use solana_sdk::pubkey::Pubkey;
use std::str::FromStr;
use sha2::{Sha256, Digest};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone)]
pub struct AresAuth;

impl AresAuth {
    pub fn new() -> AresAuth {
        AresAuth
    }

    /// Verify a Solana wallet signature
    /// Returns true if the signature is valid for the given message and pubkey
    pub fn verify_signature(
        &self,
        message: &[u8],
        signature: &str,
        pubkey: &str,
    ) -> Result<bool, String> {
        // Parse the signature
        let sig = Signature::from_str(signature)
            .map_err(|e| format!("Invalid signature encoding: {}", e))?;

        // Parse the pubkey
        let pubkey_parsed = Pubkey::from_str(pubkey)
            .map_err(|e| format!("Invalid pubkey: {}", e))?;

        // Solana signs messages with a specific format: 
        // "solana offchain message" prefix + message
        let mut message_with_prefix = Vec::new();
        message_with_prefix.extend_from_slice(b"\xffsolana offchain message");
        message_with_prefix.push(message.len() as u8);
        message_with_prefix.extend_from_slice(message);

        // Hash the message (Solana uses SHA256)
        let mut hasher = Sha256::new();
        hasher.update(&message_with_prefix);
        let message_hash = hasher.finalize();

        // Verify using ed25519 verification
        // Solana signatures are ed25519, verify against the message hash
        use ed25519_dalek::{Verifier, PublicKey, Signature as EdSignature};
        
        let public_key = PublicKey::from_bytes(&pubkey_parsed.to_bytes())
            .map_err(|e| format!("Invalid public key: {}", e))?;
        
        let sig_bytes = sig.as_ref();
        if sig_bytes.len() != 64 {
            return Err("Signature must be 64 bytes".to_string());
        }
        
        // Convert signature bytes to fixed-size array
        let mut sig_array = [0u8; 64];
        sig_array.copy_from_slice(&sig_bytes[..64]);
        let ed_sig = EdSignature::from_bytes(&sig_array)
            .map_err(|e| format!("Invalid signature: {}", e))?;

        Ok(public_key.verify(&message_hash, &ed_sig).is_ok())
    }

    /// Create a challenge message for the client to sign
    pub fn create_challenge(wallet: &str, timestamp: i64) -> String {
        format!("Shadow authentication challenge for {} at {}", wallet, timestamp)
    }

    /// Verify a signed challenge
    pub fn verify_challenge(
        &self,
        wallet: &str,
        signature: &str,
        timestamp: i64,
    ) -> Result<bool, String> {
        let challenge = Self::create_challenge(wallet, timestamp);
        self.verify_signature(challenge.as_bytes(), signature, wallet)
    }
}

impl Default for AresAuth {
    fn default() -> AresAuth {
        AresAuth::new()
    }
}

#[derive(Deserialize, Serialize, Debug)]
pub struct AuthHeader {
    pub wallet: String,
    pub signature: String,
    pub timestamp: i64,
}

impl AuthHeader {
    /// Extract auth header from request
    pub fn from_header(header_value: &str) -> Result<Self, String> {
        serde_json::from_str(header_value)
            .map_err(|e| format!("Invalid auth header: {}", e))
    }

    /// Verify the auth header
    pub fn verify(&self, ares: &AresAuth) -> Result<bool, String> {
        // Check timestamp is recent (within 5 minutes)
        let now = chrono::Utc::now().timestamp();
        if (now - self.timestamp).abs() > 300 {
            return Err("Challenge expired".to_string());
        }

        ares.verify_challenge(&self.wallet, &self.signature, self.timestamp)
    }
}

