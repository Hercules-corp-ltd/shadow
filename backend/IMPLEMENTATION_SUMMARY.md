# Backend Implementation Summary - Greek Mythology Theme

## 🏛️ Modules Implemented

### 1. **Ares** (`ares.rs`) - God of War and Security
- **Purpose**: Wallet signature verification and authentication
- **Features**:
  - Solana wallet signature verification using ed25519
  - Challenge-response authentication with timestamp validation
  - Auth header parsing and verification
- **Usage**: Protects all write endpoints (profile updates, site registration, domain management)

### 2. **Olympus** (`olympus.rs`) - The Pantheon (CA Domain System)
- **Purpose**: Certificate Authority domain registry for Shadow sites
- **Features**:
  - Domain registration (`.shadow` domains)
  - Domain verification and ownership tracking
  - Domain transfer functionality
  - Search and listing by owner/program
- **Database**: `domains` collection with indexes on `owner_pubkey`, `verified`, and `program_address`
- **Domain Format**: Must end with `.shadow` (e.g., `example.shadow`)

### 3. **Apollo** (`apollo.rs`) - God of Truth and Light
- **Purpose**: Input validation and sanitization
- **Features**:
  - Solana pubkey validation
  - Domain name format validation
  - IPFS CID validation
  - Arweave transaction ID validation
  - Search query validation
  - String sanitization (removes control characters)
  - Limit parameter validation (1-100)

### 4. **Artemis** (`artemis.rs`) - Goddess of the Hunt
- **Purpose**: Rate limiting and request throttling
- **Features**:
  - Per-client rate limiting (60 requests/minute default)
  - Client identification by wallet or IP address
  - Automatic cleanup of old entries
  - Configurable rate limits

### 5. **Hermes** (`websocket.rs`) - Messenger God
- **Purpose**: Real-time WebSocket communication
- **Features**:
  - Subscribe/unsubscribe to wallet or program events
  - Ping/pong heartbeat
  - Message broker architecture (ready for Redis integration)
  - Topic-based subscriptions (`wallet:{address}`, `program:{address}`)

## 🔐 Authentication Flow

1. Client requests a challenge from the server
2. Server generates: `"Shadow authentication challenge for {wallet} at {timestamp}"`
3. Client signs the challenge with their wallet
4. Client sends auth header: `X-Shadow-Auth: {"wallet":"...","signature":"...","timestamp":...}`
5. Server verifies:
   - Signature is valid
   - Timestamp is within 5 minutes
   - Wallet matches the resource being modified

## 🌐 Domain System (Olympus CA)

### Domain Registration
```json
POST /api/domains
{
  "domain": "example.shadow",
  "program_address": "ProgramAddress...",
  "owner_pubkey": "WalletAddress..."
}
```

### Domain Verification
After on-chain verification, mark domain as verified:
```json
POST /api/domains/{domain}/verify
```

### Domain Lookup
```json
GET /api/domains/{domain}
GET /api/domains/owner/{wallet}
GET /api/domains/search?q={query}
```

## 📡 API Endpoints Updated

### Protected Endpoints (Require Ares Auth)
- `POST /api/profiles` - Create profile (optional auth)
- `PUT /api/profiles/{wallet}` - Update profile (required auth)
- `POST /api/sites` - Register site (required auth)
- `PUT /api/sites/{program_address}` - Update site (required auth)
- `POST /api/domains` - Register domain (required auth)
- `PUT /api/domains/{domain}` - Update domain (required auth)
- `POST /api/domains/{domain}/verify` - Verify domain (required auth)

### Public Endpoints (Rate Limited)
- `GET /api/profiles/search` - Search profiles
- `GET /api/profiles/{wallet}` - Get profile
- `GET /api/sites/search` - Search sites
- `GET /api/sites/{program_address}` - Get site
- `GET /api/domains/search` - Search domains
- `GET /api/domains/{domain}` - Get domain
- `GET /api/domains/owner/{wallet}` - List owner domains

## 🔧 Site Registration Update

Previously used UUID placeholder. Now:
1. Validates `owner_pubkey` is a valid Solana address
2. Verifies the program address exists on-chain
3. Uses the actual program address (not UUID)
4. Requires wallet signature authentication

## 🗄️ Database Schema Updates

### New Collection: `domains`
```rust
{
  _id: String,                    // domain name (e.g., "example.shadow")
  owner_pubkey: String,          // Wallet that owns the domain
  program_address: String,       // Solana program it points to
  verified: bool,                 // On-chain verification status
  created_at: DateTime,
  updated_at: DateTime,
  expires_at: Option<DateTime>
}
```

### Indexes Created
- `domains`: `{owner_pubkey: 1, verified: 1}`
- `domains`: `{program_address: 1}`

## 🚀 Next Steps

1. **Redis Integration**: Replace in-memory rate limiter and WebSocket broker with Redis
2. **On-chain Verification**: Implement actual Solana program verification for domains
3. **Event Subscriptions**: Connect Hermes WebSocket to Solana WebSocket for real-time events
4. **Domain Expiration**: Implement domain renewal and expiration logic
5. **Testing**: Add unit and integration tests for all modules
6. **Documentation**: API documentation with examples

## 📝 Notes

- All modules follow Greek mythology naming convention
- Error handling uses `ShadowError` enum with proper HTTP status codes
- Rate limiting is per-client (wallet or IP)
- Domain names must be valid and end with `.shadow`
- Authentication uses Solana's standard message signing format


