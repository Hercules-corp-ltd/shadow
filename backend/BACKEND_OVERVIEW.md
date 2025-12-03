# Hephaestus Backend Overview 🔨

> The forge of Shadow - Rust backend powered by Actix-Web

## Current Architecture

### Core Modules

1. **`main.rs`** - Server initialization, routing, middleware
2. **`api.rs`** - Health check endpoint
3. **`handlers.rs`** - Request handlers for all API routes
4. **`db.rs`** - MongoDB operations (users, sites)
5. **`storage.rs`** - IPFS (Pinata) and Arweave (Bundlr) integration
6. **`solana.rs`** - Solana RPC client for account/program queries
7. **`websocket.rs`** - WebSocket handler (currently echo server)
8. **`error.rs`** - Custom error types

### API Endpoints

#### Health & Status
- `GET /api/health` - Health check

#### Profiles (Users)
- `GET /api/profiles/search?q={query}&limit={limit}` - Search public profiles
- `GET /api/profiles/{wallet}` - Get profile by wallet address
- `POST /api/profiles` - Create/update profile
- `PUT /api/profiles/{wallet}` - Update profile

#### Sites
- `GET /api/sites/search?q={query}&limit={limit}` - Search sites
- `GET /api/sites/{program_address}` - Get site by program address
- `POST /api/sites` - Register new site
- `PUT /api/sites/{program_address}` - Update site
- `GET /api/sites/{program_address}/content` - Get site content from IPFS/Arweave

#### Storage
- `POST /api/upload/ipfs` - Upload file to IPFS (Pinata)
- `POST /api/upload/arweave` - Upload file to Arweave (Bundlr)

#### Solana
- `GET /api/solana/search?q={query}` - Search Solana accounts/programs

#### WebSocket
- `GET /api/ws` - WebSocket connection (currently echo server)

## Current Status

### ✅ Working
- MongoDB connection and CRUD operations
- Profile management (create, read, update, search)
- Site management (create, read, update, search)
- IPFS upload/download via Pinata
- Arweave upload/download via Bundlr
- Solana account/program search
- Basic WebSocket support
- CORS enabled for frontend
- Error handling with custom error types

### ⚠️ Needs Improvement
1. **WebSocket** - Currently just echo server, needs real-time Solana event subscriptions
2. **Site Registration** - Uses UUID placeholder instead of actual Solana program address
3. **Authentication** - No wallet signature verification for profile/site updates
4. **Bundlr Integration** - Simplified implementation, should use proper Bundlr SDK
5. **Rate Limiting** - No rate limiting on API endpoints
6. **Validation** - Limited input validation on requests
7. **Logging** - Basic tracing setup, could be more comprehensive
8. **Testing** - No unit/integration tests

## Database Schema

### Users Collection
```rust
{
  _id: String,              // wallet_pubkey
  profile_cid: Option<String>,  // IPFS/Arweave CID
  is_public: bool,
  created_at: DateTime,
  updated_at: DateTime
}
```

### Sites Collection
```rust
{
  _id: String,              // program_address
  owner_pubkey: String,
  storage_cid: String,      // IPFS/Arweave CID
  name: Option<String>,
  description: Option<String>,
  created_at: DateTime,
  updated_at: DateTime
}
```

## Environment Variables

Required:
- `DATABASE_URL` - MongoDB connection string
- `SOLANA_RPC_URL` - Solana RPC endpoint
- `SOLANA_WS_URL` - Solana WebSocket endpoint
- `PORT` - Server port (default: 8080)

Optional (for storage):
- `PINATA_API_KEY` - IPFS via Pinata
- `PINATA_SECRET` - IPFS via Pinata
- `BUNDLR_NODE_URL` - Arweave via Bundlr
- `BUNDLR_PRIVATE_KEY` - Arweave via Bundlr

## Potential Next Steps

1. **Wallet Authentication**
   - Add signature verification for profile/site updates
   - Verify wallet owns the resources being modified

2. **Real-time WebSocket**
   - Subscribe to Solana program events
   - Broadcast updates to connected clients
   - Room-based subscriptions (by wallet/program)

3. **On-chain Integration**
   - Verify program addresses exist on-chain
   - Query program data from Solana
   - Sync on-chain state with database

4. **Rate Limiting**
   - Add rate limiting middleware
   - Protect against abuse

5. **Input Validation**
   - Validate wallet addresses
   - Validate CIDs
   - Sanitize user input

6. **Testing**
   - Unit tests for database operations
   - Integration tests for API endpoints
   - Mock Solana RPC for testing

7. **Performance**
   - Add caching layer (Redis?)
   - Optimize database queries
   - Connection pooling

8. **Monitoring**
   - Better logging structure
   - Metrics collection
   - Health check improvements

## Running the Backend

```bash
cd backend
cargo run
```

Or with environment variables:
```bash
DATABASE_URL=mongodb://localhost:27017/shadow cargo run
```

## Testing Database

```bash
cargo run --bin test_db
```



