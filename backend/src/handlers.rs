use actix_web::{web, HttpRequest, HttpResponse, Result as ActixResult};
use crate::db;
use crate::error::ShadowError;
use crate::storage::{PinataStorage, BundlrStorage};
use crate::solana::SolanaClient;
use crate::ares::{AresAuth, AuthHeader};
use crate::apollo::ApolloValidator;
use crate::artemis::ArtemisRateLimiter;
use crate::olympus::OlympusCA;
use serde::{Deserialize, Serialize};
use mongodb::Database;

#[derive(Deserialize)]
pub struct CreateProfileRequest {
    pub wallet: String,
    pub profile_cid: String,
    pub is_public: bool,
}

#[derive(Deserialize)]
pub struct UpdateProfileRequest {
    pub profile_cid: Option<String>,
    pub is_public: Option<bool>,
}

#[derive(Serialize)]
pub struct ProfileResponse {
    pub wallet_pubkey: String,
    pub profile_cid: Option<String>,
    pub is_public: bool,
    pub exists: bool,
}

pub async fn search_profiles(
    db: web::Data<Database>,
    query: web::Query<SearchQuery>,
    apollo: web::Data<ApolloValidator>,
    artemis: web::Data<ArtemisRateLimiter>,
    req: HttpRequest,
) -> ActixResult<HttpResponse, ShadowError> {
    // Rate limiting
    let client_ip = req.peer_addr().map(|a| a.ip().to_string());
    let key = ArtemisRateLimiter::get_client_key(client_ip.as_deref(), None);
    artemis.check_rate_limit(&key)
        .map_err(|e| ShadowError::BadRequest(e))?;

    // Validation
    ApolloValidator::validate_search_query(&query.q)?;
    let limit = ApolloValidator::validate_limit(query.limit)?;

    let users = db::search_users(&db, &query.q, limit)
        .await?;

    Ok(HttpResponse::Ok().json(users))
}

pub async fn get_profile(
    db: web::Data<Database>,
    path: web::Path<String>,
) -> ActixResult<HttpResponse, ShadowError> {
    let wallet = path.into_inner();
    
    match db::get_user(&db, &wallet).await? {
        Some(user) => {
            Ok(HttpResponse::Ok().json(ProfileResponse {
                wallet_pubkey: user.wallet_pubkey.clone(),
                profile_cid: user.profile_cid.clone(),
                is_public: user.is_public,
                exists: true,
            }))
        }
        None => {
            // Return exists: false if not found, but don't error
            Ok(HttpResponse::Ok().json(ProfileResponse {
                wallet_pubkey: wallet,
                profile_cid: None,
                is_public: false,
                exists: false,
            }))
        }
    }
}

pub async fn create_profile_route(
    db: web::Data<Database>,
    body: web::Json<CreateProfileRequest>,
    ares: web::Data<AresAuth>,
    apollo: web::Data<ApolloValidator>,
    req: HttpRequest,
) -> ActixResult<HttpResponse, ShadowError> {
    // Validate wallet address
    ApolloValidator::validate_pubkey(&body.wallet)?;
    
    // Validate CID
    ApolloValidator::validate_ipfs_cid(&body.profile_cid)?;

    // Verify authentication
    if let Some(auth_header) = req.headers().get("X-Shadow-Auth") {
        if let Ok(auth_str) = auth_header.to_str() {
            if let Ok(auth) = AuthHeader::from_header(auth_str) {
                if auth.wallet != body.wallet {
                    return Err(ShadowError::Unauthorized.into());
                }
                auth.verify(&ares)
                    .map_err(|e| ShadowError::Unauthorized)?;
            }
        }
    }

    db::create_or_update_user(
        &db,
        &body.wallet,
        Some(&body.profile_cid),
        body.is_public,
    ).await?;

    Ok(HttpResponse::Created().json(serde_json::json!({
        "success": true,
        "wallet": body.wallet
    })))
}

pub async fn update_profile(
    db: web::Data<Database>,
    path: web::Path<String>,
    body: web::Json<UpdateProfileRequest>,
    ares: web::Data<AresAuth>,
    apollo: web::Data<ApolloValidator>,
    req: HttpRequest,
) -> ActixResult<HttpResponse, ShadowError> {
    let wallet = path.into_inner();
    
    // Validate wallet
    ApolloValidator::validate_pubkey(&wallet)?;

    // Verify authentication - must own the profile
    let auth_header = req.headers().get("X-Shadow-Auth")
        .ok_or_else(|| ShadowError::Unauthorized)?
        .to_str()
        .map_err(|_| ShadowError::Unauthorized)?;
    
    let auth = AuthHeader::from_header(auth_header)?;
    if auth.wallet != wallet {
        return Err(ShadowError::Unauthorized.into());
    }
    
    auth.verify(&ares)
        .map_err(|_| ShadowError::Unauthorized)?;
    
    let user = db::get_user(&db, &wallet).await?
        .ok_or_else(|| ShadowError::NotFound("Profile not found".to_string()))?;

    // Validate CID if provided
    if let Some(ref cid) = body.profile_cid {
        ApolloValidator::validate_ipfs_cid(cid)?;
    }

    let profile_cid = body.profile_cid.as_ref().map(|s| s.as_str()).or(user.profile_cid.as_deref());
    let is_public = body.is_public.unwrap_or(user.is_public);

    db::create_or_update_user(&db, &wallet, profile_cid, is_public).await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "success": true
    })))
}

#[derive(Deserialize)]
pub struct SearchQuery {
    pub q: String,
    #[serde(default)]
    pub limit: Option<i64>,
}

#[derive(Deserialize)]
pub struct RegisterSiteRequest {
    pub owner_pubkey: String,
    pub storage_cid: String,
    pub name: Option<String>,
    pub description: Option<String>,
}

pub async fn search_sites(
    db: web::Data<Database>,
    query: web::Query<SearchQuery>,
) -> ActixResult<HttpResponse, ShadowError> {
    let sites = db::search_sites(&db, &query.q, query.limit.unwrap_or(10))
        .await?;

    Ok(HttpResponse::Ok().json(sites))
}

pub async fn get_site(
    db: web::Data<Database>,
    path: web::Path<String>,
) -> ActixResult<HttpResponse, ShadowError> {
    let program_address = path.into_inner();
    
    let site = db::get_site(&db, &program_address).await?
        .ok_or_else(|| ShadowError::NotFound("Site not found".to_string()))?;

    Ok(HttpResponse::Ok().json(site))
}

pub async fn register_site(
    db: web::Data<Database>,
    body: web::Json<RegisterSiteRequest>,
    solana_rpc: web::Data<String>,
    ares: web::Data<AresAuth>,
    apollo: web::Data<ApolloValidator>,
    req: HttpRequest,
) -> ActixResult<HttpResponse, ShadowError> {
    // Validate inputs
    ApolloValidator::validate_pubkey(&body.owner_pubkey)?;
    ApolloValidator::validate_ipfs_cid(&body.storage_cid)?;

    // Verify authentication
    let auth_header = req.headers().get("X-Shadow-Auth")
        .ok_or_else(|| ShadowError::Unauthorized)?
        .to_str()
        .map_err(|_| ShadowError::Unauthorized)?;
    
    let auth = AuthHeader::from_header(auth_header)?;
    if auth.wallet != body.owner_pubkey {
        return Err(ShadowError::Unauthorized.into());
    }
    
    auth.verify(&ares)
        .map_err(|_| ShadowError::Unauthorized)?;

    // Verify program address exists on-chain
    let client = SolanaClient::new(solana_rpc.to_string());
    let program_address = match client.search_program(&body.owner_pubkey) {
        Ok(Some(_)) => body.owner_pubkey.clone(),
        _ => return Err(ShadowError::BadRequest("Program address not found on-chain".to_string()).into()),
    };
    
    db::create_or_update_site(
        &db,
        &program_address,
        &body.owner_pubkey,
        &body.storage_cid,
        body.name.as_deref(),
        body.description.as_deref(),
    ).await?;

    Ok(HttpResponse::Created().json(serde_json::json!({
        "success": true,
        "program_address": program_address
    })))
}

pub async fn update_site(
    db: web::Data<Database>,
    path: web::Path<String>,
    body: web::Json<RegisterSiteRequest>,
) -> ActixResult<HttpResponse, ShadowError> {
    let program_address = path.into_inner();
    
    db::create_or_update_site(
        &db,
        &program_address,
        &body.owner_pubkey,
        &body.storage_cid,
        body.name.as_deref(),
        body.description.as_deref(),
    ).await?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "success": true
    })))
}

pub async fn get_site_content(
    db: web::Data<Database>,
    pinata: web::Data<PinataStorage>,
    bundlr: web::Data<BundlrStorage>,
    path: web::Path<String>,
) -> ActixResult<HttpResponse, ShadowError> {
    let program_address = path.into_inner();
    
    let site = db::get_site(&db, &program_address).await?
        .ok_or_else(|| ShadowError::NotFound("Site not found".to_string()))?;

    let content = if site.storage_cid.starts_with("ipfs://") {
        pinata.get(&site.storage_cid).await
            .map_err(|e| ShadowError::Storage(e))?
    } else if site.storage_cid.starts_with("arweave://") {
        bundlr.get(&site.storage_cid).await
            .map_err(|e| ShadowError::Storage(e))?
    } else {
        return Err(ShadowError::BadRequest("Invalid storage CID".to_string()));
    };

    Ok(HttpResponse::Ok()
        .content_type("text/html")
        .body(content))
}

pub async fn upload_ipfs(
    pinata: web::Data<PinataStorage>,
    body: web::Bytes,
) -> ActixResult<HttpResponse, ShadowError> {
    let cid = pinata.upload(&body, "upload").await
        .map_err(|e| ShadowError::Storage(e))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "cid": cid
    })))
}

pub async fn upload_arweave(
    bundlr: web::Data<BundlrStorage>,
    body: web::Bytes,
) -> ActixResult<HttpResponse, ShadowError> {
    let tx_id = bundlr.upload(&body, vec![]).await
        .map_err(|e| ShadowError::Storage(e))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "tx_id": tx_id
    })))
}

pub async fn search_solana(
    solana_rpc_url: web::Data<String>,
    query: web::Query<SearchQuery>,
) -> ActixResult<HttpResponse, ShadowError> {
    let client = SolanaClient::new(solana_rpc_url.to_string());
    
    // Try to parse as pubkey first
    if let Ok(account) = client.search_account(&query.q) {
        if let Some(acc) = account {
            return Ok(HttpResponse::Ok().json(serde_json::json!({
                "type": "account",
                "data": acc
            })));
        }
    }

    // Try as program
    if let Ok(program) = client.search_program(&query.q) {
        if let Some(prog) = program {
            return Ok(HttpResponse::Ok().json(serde_json::json!({
                "type": "program",
                "data": prog
            })));
        }
    }

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "type": "none",
        "data": null
    })))
}

// ========== Olympus Domain Handlers ==========

#[derive(Deserialize)]
pub struct RegisterDomainRequest {
    pub domain: String,
    pub program_address: String,
    pub owner_pubkey: String,
}

pub async fn register_domain(
    olympus: web::Data<OlympusCA>,
    body: web::Json<RegisterDomainRequest>,
    ares: web::Data<AresAuth>,
    apollo: web::Data<ApolloValidator>,
    req: HttpRequest,
) -> ActixResult<HttpResponse, ShadowError> {
    // Validate inputs
    ApolloValidator::validate_domain(&body.domain)?;
    ApolloValidator::validate_pubkey(&body.owner_pubkey)?;
    ApolloValidator::validate_pubkey(&body.program_address)?;

    // Verify authentication
    let auth_header = req.headers().get("X-Shadow-Auth")
        .ok_or_else(|| ShadowError::Unauthorized)?
        .to_str()
        .map_err(|_| ShadowError::Unauthorized)?;
    
    let auth = AuthHeader::from_header(auth_header)?;
    if auth.wallet != body.owner_pubkey {
        return Err(ShadowError::Unauthorized.into());
    }
    
    auth.verify(&ares)
        .map_err(|_| ShadowError::Unauthorized)?;

    // Register domain
    olympus.register_domain(
        &body.domain,
        &body.owner_pubkey,
        &body.program_address,
    ).await
    .map_err(|e| ShadowError::BadRequest(e))?;

    Ok(HttpResponse::Created().json(serde_json::json!({
        "success": true,
        "domain": body.domain
    })))
}

pub async fn get_domain(
    olympus: web::Data<OlympusCA>,
    path: web::Path<String>,
) -> ActixResult<HttpResponse, ShadowError> {
    let domain = path.into_inner();
    
    let domain_data = olympus.get_domain(&domain).await
        .map_err(|e| ShadowError::BadRequest(e))?
        .ok_or_else(|| ShadowError::NotFound("Domain not found".to_string()))?;

    Ok(HttpResponse::Ok().json(domain_data))
}

pub async fn search_domains(
    olympus: web::Data<OlympusCA>,
    query: web::Query<SearchQuery>,
    apollo: web::Data<ApolloValidator>,
) -> ActixResult<HttpResponse, ShadowError> {
    ApolloValidator::validate_search_query(&query.q)?;
    let limit = ApolloValidator::validate_limit(query.limit)?;

    let domains = olympus.search_domains(&query.q, limit).await
        .map_err(|e| ShadowError::BadRequest(e))?;

    Ok(HttpResponse::Ok().json(domains))
}

pub async fn update_domain(
    olympus: web::Data<OlympusCA>,
    path: web::Path<String>,
    body: web::Json<RegisterDomainRequest>,
    ares: web::Data<AresAuth>,
    apollo: web::Data<ApolloValidator>,
    req: HttpRequest,
) -> ActixResult<HttpResponse, ShadowError> {
    let domain = path.into_inner();
    
    // Validate
    ApolloValidator::validate_domain(&domain)?;
    ApolloValidator::validate_pubkey(&body.program_address)?;

    // Verify ownership
    let domain_data = olympus.get_domain(&domain).await
        .map_err(|e| ShadowError::BadRequest(e))?
        .ok_or_else(|| ShadowError::NotFound("Domain not found".to_string()))?;

    // Verify authentication
    let auth_header = req.headers().get("X-Shadow-Auth")
        .ok_or_else(|| ShadowError::Unauthorized)?
        .to_str()
        .map_err(|_| ShadowError::Unauthorized)?;
    
    let auth = AuthHeader::from_header(auth_header)?;
    if auth.wallet != domain_data.owner_pubkey {
        return Err(ShadowError::Unauthorized.into());
    }
    
    auth.verify(&ares)
        .map_err(|_| ShadowError::Unauthorized)?;

    // Update domain
    olympus.register_domain(
        &domain,
        &domain_data.owner_pubkey,
        &body.program_address,
    ).await
    .map_err(|e| ShadowError::BadRequest(e))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "success": true
    })))
}

pub async fn verify_domain(
    olympus: web::Data<OlympusCA>,
    path: web::Path<String>,
    ares: web::Data<AresAuth>,
    req: HttpRequest,
) -> ActixResult<HttpResponse, ShadowError> {
    let domain = path.into_inner();
    
    // Verify ownership
    let domain_data = olympus.get_domain(&domain).await
        .map_err(|e| ShadowError::BadRequest(e))?
        .ok_or_else(|| ShadowError::NotFound("Domain not found".to_string()))?;

    // Verify authentication
    let auth_header = req.headers().get("X-Shadow-Auth")
        .ok_or_else(|| ShadowError::Unauthorized)?
        .to_str()
        .map_err(|_| ShadowError::Unauthorized)?;
    
    let auth = AuthHeader::from_header(auth_header)?;
    if auth.wallet != domain_data.owner_pubkey {
        return Err(ShadowError::Unauthorized.into());
    }
    
    auth.verify(&ares)
        .map_err(|_| ShadowError::Unauthorized)?;

    // Mark as verified (after on-chain verification)
    olympus.verify_domain(&domain).await
        .map_err(|e| ShadowError::BadRequest(e))?;

    Ok(HttpResponse::Ok().json(serde_json::json!({
        "success": true,
        "verified": true
    })))
}

pub async fn list_owner_domains(
    olympus: web::Data<OlympusCA>,
    path: web::Path<String>,
) -> ActixResult<HttpResponse, ShadowError> {
    let wallet = path.into_inner();
    
    let domains = olympus.list_owner_domains(&wallet).await
        .map_err(|e| ShadowError::BadRequest(e))?;

    Ok(HttpResponse::Ok().json(domains))
}
