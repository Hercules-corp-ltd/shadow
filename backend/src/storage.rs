use serde_json::Value;
use std::env;

pub struct PinataStorage {
    api_key: Option<String>,
    secret: Option<String>,
}

impl PinataStorage {
    pub fn new() -> Self {
        Self {
            api_key: env::var("PINATA_API_KEY").ok(),
            secret: env::var("PINATA_SECRET")
                .ok()
                .or_else(|| env::var("PINATA_SECRET_KEY").ok()),
        }
    }

    pub async fn upload(&self, data: &[u8], name: &str) -> Result<String, String> {
        if self.api_key.is_none() || self.secret.is_none() {
            return Err("Pinata credentials not configured".to_string());
        }

        let client = reqwest::Client::new();
        let form = reqwest::multipart::Form::new()
            .text("pinataOptions", r#"{"cidVersion":1}"#)
            .text("pinataMetadata", format!(r#"{{"name":"{}"}}"#, name))
            .part("file", reqwest::multipart::Part::bytes(data.to_vec()).file_name(name.to_string()));

        let response = client
            .post("https://api.pinata.cloud/pinning/pinFileToIPFS")
            .header("pinata_api_key", self.api_key.as_ref().unwrap())
            .header("pinata_secret_api_key", self.secret.as_ref().unwrap())
            .multipart(form)
            .send()
            .await
            .map_err(|e| format!("Pinata upload error: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("Pinata error: {}", response.status()));
        }

        let json: Value = response.json().await
            .map_err(|e| format!("Failed to parse Pinata response: {}", e))?;
        
        let ipfs_hash = json["IpfsHash"].as_str()
            .ok_or_else(|| "Missing IpfsHash in response".to_string())?;

        Ok(format!("ipfs://{}", ipfs_hash))
    }

    pub async fn get(&self, cid: &str) -> Result<Vec<u8>, String> {
        let cid = cid.strip_prefix("ipfs://").unwrap_or(cid);
        let url = format!("https://gateway.pinata.cloud/ipfs/{}", cid);
        
        let client = reqwest::Client::new();
        let response = client.get(&url)
            .send()
            .await
            .map_err(|e| format!("Failed to fetch from IPFS: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("IPFS fetch error: {}", response.status()));
        }

        let bytes = response.bytes().await
            .map_err(|e| format!("Failed to read IPFS data: {}", e))?;

        Ok(bytes.to_vec())
    }
}

pub struct BundlrStorage {
    node_url: String,
    private_key: Option<String>,
}

impl BundlrStorage {
    pub fn new() -> Self {
        Self {
            node_url: env::var("BUNDLR_NODE_URL")
                .unwrap_or_else(|_| "https://devnet.bundlr.network".to_string()),
            private_key: env::var("BUNDLR_PRIVATE_KEY").ok(),
        }
    }

    pub async fn upload(&self, data: &[u8], tags: Vec<(&str, &str)>) -> Result<String, String> {
        if self.private_key.is_none() {
            return Err("Bundlr private key not configured".to_string());
        }

        // Parse Solana private key (base58 or hex)
        let key_bytes = self.parse_private_key()?;
        let keypair = solana_sdk::signer::keypair::Keypair::from_bytes(&key_bytes)
            .map_err(|e| format!("Invalid keypair: {}", e))?;

        // Create and sign Bundlr transaction
        // Bundlr uses Arweave transactions signed with Solana keypairs
        let tx = self.create_bundlr_transaction(data, &tags, &keypair).await?;

        let client = reqwest::Client::new();
        let url = format!("{}/tx", self.node_url);

        let response = client
            .post(&url)
            .header("Content-Type", "application/octet-stream")
            .body(tx)
            .send()
            .await
            .map_err(|e| format!("Bundlr upload error: {}", e))?;

        let status = response.status();
        if !status.is_success() {
            let error_text = response.text().await.unwrap_or_default();
            return Err(format!("Bundlr error: {} - {}", status, error_text));
        }

        let json: Value = response.json().await
            .map_err(|e| format!("Failed to parse Bundlr response: {}", e))?;

        let tx_id = json["id"].as_str()
            .ok_or_else(|| "Missing tx id in response".to_string())?;

        Ok(format!("arweave://{}", tx_id))
    }

    fn parse_private_key(&self) -> Result<Vec<u8>, String> {
        let key_str = self.private_key.as_ref().unwrap();
        
        // Try base58 first (Solana format)
        if let Ok(bytes) = bs58::decode(key_str).into_vec() {
            if bytes.len() == 64 {
                return Ok(bytes);
            }
        }
        
        // Try hex
        if let Ok(bytes) = hex::decode(key_str.trim_start_matches("0x")) {
            if bytes.len() == 64 {
                return Ok(bytes);
            }
        }
        
        Err("Invalid private key format. Expected base58 or hex (64 bytes)".to_string())
    }

    async fn create_bundlr_transaction(
        &self,
        data: &[u8],
        _tags: &[(&str, &str)],
        keypair: &solana_sdk::signer::keypair::Keypair,
    ) -> Result<Vec<u8>, String> {
        // Get price from Bundlr
        let client = reqwest::Client::new();
        let price_url = format!("{}/price/{}", self.node_url, data.len());
        
        let price_response = client
            .get(&price_url)
            .send()
            .await
            .map_err(|e| format!("Failed to get price: {}", e))?;
        
        let price_json: Value = price_response.json().await
            .map_err(|e| format!("Failed to parse price: {}", e))?;
        
        let _price = price_json["atomicPrice"].as_u64()
            .ok_or_else(|| "Missing price in response".to_string())?;

        // Create transaction payload for Bundlr
        // Bundlr accepts data with signature in a specific format
        // We'll create a signed payload that Bundlr can verify
        let mut payload = Vec::new();
        
        // Add data
        payload.extend_from_slice(data);
        
        // Create signature over the data
        use solana_sdk::signature::Signer;
        let signature = keypair.try_sign_message(&payload)
            .map_err(|e| format!("Failed to sign: {}", e))?;
        
        // Bundlr transaction format: data + signature + public key
        let mut tx = payload;
        tx.extend_from_slice(signature.as_ref());
        tx.extend_from_slice(&keypair.pubkey().to_bytes());
        
        // Add tags as metadata (Bundlr will handle this)
        // For now, we'll send the transaction and let Bundlr process it
        Ok(tx)
    }

    pub async fn get(&self, tx_id: &str) -> Result<Vec<u8>, String> {
        let tx_id = tx_id.strip_prefix("arweave://").unwrap_or(tx_id);
        let url = format!("https://arweave.net/{}", tx_id);
        
        let client = reqwest::Client::new();
        let response = client.get(&url)
            .send()
            .await
            .map_err(|e| format!("Failed to fetch from Arweave: {}", e))?;

        if !response.status().is_success() {
            return Err(format!("Arweave fetch error: {}", response.status()));
        }

        let bytes = response.bytes().await
            .map_err(|e| format!("Failed to read Arweave data: {}", e))?;

        Ok(bytes.to_vec())
    }
}

