# Shadow Project Plan 🏛️

> A Tor-inspired, wallet-only pseudonymous web platform built on Solana

## 📊 Project Status Overview

### ✅ Completed

#### Backend (Hephaestus Forge)
- ✅ **Ares** - Authentication & Security Module
  - Solana wallet signature verification
  - Challenge-response authentication
  - Auth header parsing and validation
  
- ✅ **Olympus** - CA Domain System
  - `.shadow` domain registration
  - Domain verification and ownership tracking
  - Domain search and listing
  - Database schema and indexes

- ✅ **Apollo** - Validation Module
  - Input validation (pubkeys, domains, CIDs, TX IDs)
  - String sanitization
  - Parameter validation (limits, search queries)

- ✅ **Artemis** - Rate Limiting
  - Per-client rate limiting (60 req/min)
  - Wallet/IP-based identification
  - Automatic cleanup

- ✅ **Hermes** - WebSocket Messenger
  - Real-time subscription system
  - Topic-based messaging (wallet/program)
  - Ping/pong heartbeat

- ✅ **Core Backend Infrastructure**
  - MongoDB database with indexes
  - Profile management (CRUD)
  - Site management (CRUD)
  - IPFS/Arweave storage integration
  - Solana RPC client
  - Error handling system
  - CORS configuration

#### Frontend (App)
- ✅ **Wallet System**
  - Device-local Solana wallet generation
  - Password-based encryption (AES-256-GCM)
  - Wallet export/import functionality
  - Secure localStorage storage

- ✅ **Removed Dependencies**
  - Privy authentication removed
  - Gmail login removed
  - All external auth dependencies cleaned

#### Project Structure
- ✅ **Greek Mythology Theme**
  - Commit message template (`.gitmessage`)
  - Greek-themed naming guide (`GREEK_COMMITS.md`)
  - Module naming convention established
  - SDK renamed to "Hermes SDK"

- ✅ **Documentation**
  - Backend overview (`backend/BACKEND_OVERVIEW.md`)
  - Implementation summary (`backend/IMPLEMENTATION_SUMMARY.md`)
  - Project README updated

---

## 🚧 In Progress

- 🔄 **Frontend Design** (Designer working on this)
  - UI/UX improvements
  - Mobile-first responsive design
  - Native look and feel for iOS/Android/Desktop

---

## 📋 What's Left To Do

### 🔴 High Priority

#### Backend Enhancements

1. **On-Chain Integration**
   - [ ] Connect to actual Solana programs (Shadow Profiles, Shadow Registry)
   - [ ] Implement on-chain domain verification
   - [ ] Sync on-chain state with database
   - [ ] Verify program ownership before site registration
   - [ ] Query program data from Solana

2. **Hermes WebSocket Real-Time Events**
   - [ ] Connect to Solana WebSocket for account changes
   - [ ] Subscribe to program events
   - [ ] Broadcast updates to connected clients
   - [ ] Room-based subscriptions
   - [ ] Redis integration for distributed WebSocket (optional)

3. **Domain System Completion**
   - [ ] Domain expiration and renewal logic
   - [ ] Domain transfer on-chain verification
   - [ ] Domain metadata (description, tags, etc.)
   - [ ] Domain DNS-like resolution

4. **Authentication Improvements**
   - [ ] Nonce-based challenge system (prevent replay attacks)
   - [ ] JWT tokens for session management (optional)
   - [ ] Multi-signature support
   - [ ] Wallet connection persistence

5. **Storage Enhancements**
   - [ ] Proper Bundlr SDK integration (currently simplified)
   - [ ] File upload size limits
   - [ ] Content type validation
   - [ ] Storage quota management

6. **Rate Limiting & Security**
   - [ ] Redis-backed rate limiting (replace in-memory)
   - [ ] IP-based blocking for abuse
   - [ ] Request size limits
   - [ ] DDoS protection

#### Frontend Integration

7. **Frontend-Backend Integration**
   - [ ] Connect frontend to new authentication system
   - [ ] Implement domain registration UI
   - [ ] Wallet signature flow in frontend
   - [ ] WebSocket client integration
   - [ ] Error handling and user feedback

8. **Site Builder Features**
   - [ ] Site creation wizard
   - [ ] Domain selection/registration UI
   - [ ] Content upload interface
   - [ ] Site preview functionality
   - [ ] Site management dashboard

#### Testing & Quality

9. **Testing**
   - [ ] Unit tests for all modules (Ares, Olympus, Apollo, Artemis, Hermes)
   - [ ] Integration tests for API endpoints
   - [ ] Database operation tests
   - [ ] Signature verification tests
   - [ ] WebSocket connection tests
   - [ ] End-to-end tests

10. **Error Handling & Logging**
    - [ ] Comprehensive error messages
    - [ ] Structured logging
    - [ ] Error tracking (Sentry or similar)
    - [ ] Health check improvements
    - [ ] Metrics collection

### 🟡 Medium Priority

11. **Performance Optimization**
    - [ ] Database query optimization
    - [ ] Caching layer (Redis)
    - [ ] Connection pooling
    - [ ] Response compression
    - [ ] CDN for static assets

12. **API Documentation**
    - [ ] OpenAPI/Swagger documentation
    - [ ] API endpoint examples
    - [ ] Authentication flow documentation
    - [ ] WebSocket protocol documentation
    - [ ] SDK usage examples

13. **Monitoring & Observability**
    - [ ] Application metrics (Prometheus)
    - [ ] Log aggregation
    - [ ] Performance monitoring
    - [ ] Alerting system

14. **Deployment**
    - [ ] Docker containerization
    - [ ] Docker Compose for local development
    - [ ] Production deployment configuration
    - [ ] Environment variable management
    - [ ] CI/CD pipeline

### 🟢 Low Priority / Future

15. **Advanced Features**
    - [ ] Multi-wallet support per user
    - [ ] Site templates
    - [ ] Site analytics
    - [ ] Content moderation
    - [ ] Search indexing (Elasticsearch)
    - [ ] GraphQL API (optional)

16. **Mobile App**
    - [ ] Capacitor integration
    - [ ] Native mobile features
    - [ ] Push notifications
    - [ ] Biometric authentication

17. **Desktop App**
    - [ ] Tauri integration
    - [ ] Native desktop features
    - [ ] System tray integration
    - [ ] Auto-update mechanism

---

## 🎯 Immediate Next Steps (Priority Order)

### Phase 1: Backend Completion (Current Focus)
1. **On-Chain Verification** ⚡
   - Implement actual Solana program verification
   - Connect to Shadow Profiles and Shadow Registry programs
   - Verify program ownership before allowing site registration

2. **WebSocket Real-Time Events** ⚡
   - Connect Hermes to Solana WebSocket
   - Implement event broadcasting
   - Test with real Solana account changes

3. **Domain System Completion** ⚡
   - Add domain expiration logic
   - Implement on-chain domain verification
   - Add domain metadata support

### Phase 2: Frontend Integration
4. **Authentication Flow**
   - Implement wallet signature in frontend
   - Connect to Ares authentication
   - Add challenge/response UI

5. **Domain Management UI**
   - Domain registration form
   - Domain list/dashboard
   - Domain verification status

6. **Site Builder**
   - Site creation flow
   - Content upload
   - Domain selection

### Phase 3: Testing & Polish
7. **Testing Suite**
   - Unit tests
   - Integration tests
   - E2E tests

8. **Documentation**
   - API documentation
   - Developer guides
   - User guides

### Phase 4: Deployment
9. **Production Ready**
   - Docker setup
   - CI/CD pipeline
   - Monitoring and logging
   - Performance optimization

---

## 📁 Project Structure

```
shadow/
├── backend/              # Hephaestus (Rust/Actix-Web)
│   ├── src/
│   │   ├── ares.rs       # Authentication
│   │   ├── olympus.rs    # Domain system
│   │   ├── apollo.rs     # Validation
│   │   ├── artemis.rs    # Rate limiting
│   │   ├── websocket.rs  # Hermes WebSocket
│   │   ├── handlers.rs   # API handlers
│   │   ├── db.rs         # Database operations
│   │   ├── storage.rs    # IPFS/Arweave
│   │   └── solana.rs     # Solana client
│   └── Cargo.toml
│
├── app/                  # Frontend (React/Vite)
│   ├── src/
│   │   ├── lib/
│   │   │   ├── wallet.ts # Wallet management
│   │   │   └── crypto.ts # Encryption
│   │   └── components/
│   └── package.json
│
├── programs/             # Solana Programs (Anchor)
│   ├── shadow-profiles/
│   └── shadow-registry/
│
├── sdk/                  # Hermes SDK (TypeScript CLI)
│   └── src/
│
└── docs/                 # Documentation
```

---

## 🔗 Key Dependencies

### Backend
- **Actix-Web** - Web framework
- **MongoDB** - Database
- **Solana SDK** - Blockchain integration
- **ed25519-dalek** - Signature verification
- **DashMap** - Concurrent rate limiting

### Frontend
- **React** - UI framework
- **Vite** - Build tool
- **Tauri** - Desktop wrapper (planned)
- **Capacitor** - Mobile wrapper (planned)

### Solana
- **Anchor** - Solana program framework
- **Shadow Profiles** - On-chain profile program
- **Shadow Registry** - Site registry program

---

## 📝 Notes

- **Greek Mythology Theme**: All modules, commits, and naming follow Greek mythology
- **Security First**: Wallet-based authentication, no emails/usernames
- **Decentralized**: IPFS/Arweave for storage, Solana for identity
- **Privacy Focused**: Pseudonymous by design, wallet-only identification

---

## 🎯 Success Metrics

- [ ] 100% of write operations require wallet authentication
- [ ] All inputs validated before processing
- [ ] Rate limiting prevents abuse
- [ ] Real-time updates via WebSocket
- [ ] Domain system fully functional
- [ ] On-chain verification working
- [ ] Frontend integrated with all backend features
- [ ] Test coverage > 80%
- [ ] API documentation complete
- [ ] Production deployment ready

---

**Last Updated**: Current session
**Status**: Backend core complete, frontend design in progress, integration next


