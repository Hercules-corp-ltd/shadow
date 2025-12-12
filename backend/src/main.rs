mod api;
mod db;
mod error;
mod handlers;
mod storage;
mod websocket;
mod solana;
mod ares;
mod olympus;
mod apollo;
mod artemis;
mod athena;
mod chronos;
mod prometheus;
mod hephaestus;
mod utils;
mod middleware;
mod config;
mod metrics;

use actix_web::{web, App, HttpServer, middleware::Logger};
use actix_cors::Cors;
use mongodb::{Client as MongoClient, options::ClientOptions, IndexModel};
use std::env;
use std::sync::Arc;
use tracing_subscriber;

#[actix_web::main]
async fn main() -> anyhow::Result<()> {
    dotenv::dotenv().ok();
    
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    
    let client_options = ClientOptions::parse(&database_url).await?;
    let client = MongoClient::with_options(client_options)?;
    let db = Arc::new(client.database("shadow"));
    
    // Create indexes for better performance
    let users_collection = db.collection::<db::User>("users");
    let users_index = IndexModel::builder()
        .keys(mongodb::bson::doc! { "is_public": 1, "_id": 1 })
        .build();
    users_collection.create_index(users_index, None).await?;
    
    let sites_collection = db.collection::<db::Site>("sites");
    let sites_index = IndexModel::builder()
        .keys(mongodb::bson::doc! { "created_at": -1 })
        .build();
    sites_collection.create_index(sites_index, None).await?;
    
    // Create indexes for Olympus domains
    let domains_collection = db.collection::<olympus::Domain>("domains");
    let domains_index = IndexModel::builder()
        .keys(mongodb::bson::doc! { "owner_pubkey": 1, "verified": 1 })
        .build();
    domains_collection.create_index(domains_index, None).await?;
    
    let domains_program_index = IndexModel::builder()
        .keys(mongodb::bson::doc! { "program_address": 1 })
        .build();
    domains_collection.create_index(domains_program_index, None).await?;

    let solana_rpc_url = env::var("SOLANA_RPC_URL")
        .unwrap_or_else(|_| "https://api.devnet.solana.com".to_string());
    
    let solana_ws_url = env::var("SOLANA_WS_URL")
        .unwrap_or_else(|_| "wss://api.devnet.solana.com".to_string());

    let port = env::var("PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()?;

    println!("🚀 Shadow backend starting on port {}", port);

    let db_clone = Arc::clone(&db);
    let solana_rpc_clone = solana_rpc_url.clone();
    let solana_ws_clone = solana_ws_url.clone();
    
    // Initialize Olympus CA (domain system) - will be created per request
    
    // Initialize Ares (authentication)
    let ares = Arc::new(ares::AresAuth::new());
    
    // Initialize Artemis (rate limiting)
    let artemis = Arc::new(artemis::ArtemisRateLimiter::new(60)); // 60 requests per minute
    
    // Initialize Apollo (validation)
    let apollo = Arc::new(apollo::ApolloValidator::new());
    
    // Initialize Athena (search indexing)
    let athena = Arc::new(athena::AthenaIndexer::new((*db_clone).clone()));
    
    // Initialize Chronos (history/bookmarks)
    let chronos = Arc::new(chronos::ChronosManager::new((*db_clone).clone()));
    
    // Initialize Prometheus (analytics)
    let prometheus = Arc::new(prometheus::PrometheusAnalytics::new((*db_clone).clone()));
    
    // Initialize Hephaestus (caching)
    let hephaestus = Arc::new(hephaestus::HephaestusCache::new(512, 3600)); // 512MB cache, 1hr TTL
    
    // Initialize metrics collector
    let metrics = Arc::new(metrics::MetricsCollector::new());
    
    // Load configuration
    let config = config::ShadowConfig::from_env()
        .map_err(|e| anyhow::anyhow!("Config error: {}", e))?;
    
    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .supports_credentials();

        App::new()
            .wrap(cors)
            .wrap(Logger::default())
            .app_data(web::Data::from(Arc::clone(&db_clone)))
            .app_data(web::Data::new(solana_rpc_clone.clone()))
            .app_data(web::Data::new(solana_ws_clone.clone()))
            .app_data(web::Data::new(storage::PinataStorage::new()))
            .app_data(web::Data::new(storage::BundlrStorage::new()))
            .app_data(web::Data::from(Arc::clone(&ares)))
            .app_data(web::Data::from(Arc::clone(&artemis)))
            .app_data(web::Data::from(Arc::clone(&apollo)))
            .app_data(web::Data::new(olympus::OlympusCA::new((*db_clone).clone())))
            .app_data(web::Data::from(Arc::clone(&athena)))
            .app_data(web::Data::from(Arc::clone(&chronos)))
            .app_data(web::Data::from(Arc::clone(&prometheus)))
            .app_data(web::Data::from(Arc::clone(&hephaestus)))
            .app_data(web::Data::from(Arc::clone(&metrics)))
            .app_data(web::Data::new(config.clone()))
            .service(
                web::scope("/api")
                    .route("/health", web::get().to(api::health))
                    .route("/profiles/search", web::get().to(handlers::search_profiles))
                    .route("/profiles/{wallet}", web::get().to(handlers::get_profile))
                    .route("/profiles", web::post().to(handlers::create_profile_route))
                    .route("/profiles/{wallet}", web::put().to(handlers::update_profile))
                    .route("/sites/search", web::get().to(handlers::search_sites))
                    .route("/sites/{program_address}", web::get().to(handlers::get_site))
                    .route("/sites", web::post().to(handlers::register_site))
                    .route("/sites/{program_address}", web::put().to(handlers::update_site))
                    .route("/sites/{program_address}/content", web::get().to(handlers::get_site_content))
                    .route("/upload/ipfs", web::post().to(handlers::upload_ipfs))
                    .route("/upload/arweave", web::post().to(handlers::upload_arweave))
                    .route("/solana/search", web::get().to(handlers::search_solana))
                    // Olympus domain endpoints
                    .route("/domains/search", web::get().to(handlers::search_domains))
                    .route("/domains/{domain}", web::get().to(handlers::get_domain))
                    .route("/domains", web::post().to(handlers::register_domain))
                    .route("/domains/{domain}", web::put().to(handlers::update_domain))
                    .route("/domains/{domain}/verify", web::post().to(handlers::verify_domain))
                    .route("/domains/owner/{wallet}", web::get().to(handlers::list_owner_domains))
                    // Athena search endpoints
                    .route("/search", web::get().to(handlers::search_content))
                    .route("/search/index", web::post().to(handlers::index_content))
                    // Chronos history/bookmarks endpoints
                    .route("/history", web::get().to(handlers::get_history))
                    .route("/history", web::post().to(handlers::record_visit))
                    .route("/history", web::delete().to(handlers::clear_history))
                    .route("/bookmarks", web::get().to(handlers::get_bookmarks))
                    .route("/bookmarks", web::post().to(handlers::add_bookmark))
                    .route("/bookmarks/{domain}", web::delete().to(handlers::remove_bookmark))
                    .route("/sessions", web::post().to(handlers::create_session))
                    .route("/sessions/active", web::get().to(handlers::get_active_sessions))
                    // Prometheus analytics endpoints
                    .route("/analytics/{domain}", web::get().to(handlers::get_analytics))
                    .route("/analytics/top", web::get().to(handlers::get_top_sites))
                    .route("/analytics/performance", web::post().to(handlers::record_performance))
                    // Hephaestus cache endpoints
                    .route("/cache/stats", web::get().to(handlers::get_cache_stats))
                    .route("/cache/clear", web::post().to(handlers::clear_cache))
                    .route("/ws", web::get().to(websocket::ws_handler))
            )
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await?;

    Ok(())
}
