#[cfg(test)]
mod tests {
    use mongodb::{Client, options::ClientOptions};
    use std::env;
    use crate::db;

    #[tokio::test]
    async fn test_database_connection() {
        dotenv::dotenv().ok();
        
        let database_url = env::var("DATABASE_URL")
            .expect("DATABASE_URL must be set");
        
        let client_options = ClientOptions::parse(&database_url).await
            .expect("Failed to parse DATABASE_URL");
        
        let client = Client::with_options(client_options)
            .expect("Failed to create MongoDB client");
        
        // Test connection
        client
            .database("admin")
            .run_command(mongodb::bson::doc! { "ping": 1 }, None)
            .await
            .expect("Failed to ping database");
        
        println!("✅ Database connection successful!");
    }

    #[tokio::test]
    async fn test_create_user() {
        dotenv::dotenv().ok();
        
        let database_url = env::var("DATABASE_URL")
            .expect("DATABASE_URL must be set");
        
        let client_options = ClientOptions::parse(&database_url).await
            .expect("Failed to parse DATABASE_URL");
        
        let client = Client::with_options(client_options)
            .expect("Failed to create MongoDB client");
        
        let db = client.database("shadow");
        
        // Test creating a user
        let test_wallet = format!("test_wallet_{}", uuid::Uuid::new_v4());
        
        db::create_or_update_user(
            &db,
            &test_wallet,
            Some("test_cid_123"),
            true,
        ).await.expect("Failed to create user");
        
        // Test retrieving the user
        let user = db::get_user(&db, &test_wallet).await
            .expect("Failed to get user");
        
        assert!(user.is_some(), "User should exist");
        let user = user.unwrap();
        assert_eq!(user.wallet_pubkey, test_wallet);
        assert_eq!(user.profile_cid, Some("test_cid_123".to_string()));
        assert_eq!(user.is_public, true);
        
        // Cleanup
        let collection = db.collection::<db::User>("users");
        collection.delete_one(mongodb::bson::doc! { "_id": &test_wallet }, None).await
            .expect("Failed to cleanup test user");
        
        println!("✅ User creation and retrieval test passed!");
    }

    #[tokio::test]
    async fn test_create_site() {
        dotenv::dotenv().ok();
        
        let database_url = env::var("DATABASE_URL")
            .expect("DATABASE_URL must be set");
        
        let client_options = ClientOptions::parse(&database_url).await
            .expect("Failed to parse DATABASE_URL");
        
        let client = Client::with_options(client_options)
            .expect("Failed to create MongoDB client");
        
        let db = client.database("shadow");
        
        // Test creating a site
        let test_program = format!("test_program_{}", uuid::Uuid::new_v4());
        let test_owner = "test_owner_123";
        let test_cid = "ipfs://test_cid_456";
        
        db::create_or_update_site(
            &db,
            &test_program,
            test_owner,
            test_cid,
            Some("Test Site"),
            Some("Test Description"),
        ).await.expect("Failed to create site");
        
        // Test retrieving the site
        let site = db::get_site(&db, &test_program).await
            .expect("Failed to get site");
        
        assert!(site.is_some(), "Site should exist");
        let site = site.unwrap();
        assert_eq!(site.program_address, test_program);
        assert_eq!(site.owner_pubkey, test_owner);
        assert_eq!(site.storage_cid, test_cid);
        assert_eq!(site.name, Some("Test Site".to_string()));
        
        // Cleanup
        let collection = db.collection::<db::Site>("sites");
        collection.delete_one(mongodb::bson::doc! { "_id": &test_program }, None).await
            .expect("Failed to cleanup test site");
        
        println!("✅ Site creation and retrieval test passed!");
    }

    #[tokio::test]
    async fn test_search_users() {
        dotenv::dotenv().ok();
        
        let database_url = env::var("DATABASE_URL")
            .expect("DATABASE_URL must be set");
        
        let client_options = ClientOptions::parse(&database_url).await
            .expect("Failed to parse DATABASE_URL");
        
        let client = Client::with_options(client_options)
            .expect("Failed to create MongoDB client");
        
        let db = client.database("shadow");
        
        // Create a test user
        let test_wallet = "test_search_123";
        db::create_or_update_user(
            &db,
            test_wallet,
            Some("test_cid"),
            true,
        ).await.expect("Failed to create user");
        
        // Test search
        let results = db::search_users(&db, "test_search", 10).await
            .expect("Failed to search users");
        
        assert!(results.len() > 0, "Should find at least one user");
        
        // Cleanup
        let collection = db.collection::<db::User>("users");
        collection.delete_one(mongodb::bson::doc! { "_id": test_wallet }, None).await
            .expect("Failed to cleanup test user");
        
        println!("✅ User search test passed!");
    }
}



