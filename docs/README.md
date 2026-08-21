# Shadow

**The Decentralized Web Browser for the New Internet**

Shadow is a revolutionary decentralized browser that transforms how we interact with the web. Built on Solana blockchain technology, it provides censorship-resistant browsing, wallet-based identity, and permanent content storage.

---

## What is Shadow?

Shadow is more than just a browser—it's a complete ecosystem for the decentralized web:

- **Token-Based URLs**: Every website gets a unique blockchain address
- **Wallet-Based Identity**: Your Solana wallet is your identity—no passwords needed
- **Decentralized Storage**: Content stored on IPFS and Arweave (permanent, censorship-resistant)
- **Privacy-First**: Optional Tor integration for IP protection
- **Multi-Platform**: Web, Desktop (Tauri), and Mobile (Flutter) applications

---

## The Pantheon Architecture

Shadow's backend is organized around Greek gods, each handling specific responsibilities:

| God | Domain | Function |
|-----|--------|----------|
| **Zeus** | Wallets | Wallet creation, import, and management |
| **Ares** | Authentication | Signature verification (SIWS) |
| **Athena** | Search | Content indexing and search |
| **Apollo** | Validation | Input validation and sanitization |
| **Poseidon** | Transactions | Transaction signing and approval |
| **Hades** | Security | Encryption and security settings |
| **Dionysus** | Tokens | SPL token operations |
| **Aphrodite** | NFTs | NFT management and transfers |
| **Prometheus** | Analytics | Site analytics and metrics |
| **Chronos** | History | Browser history and sessions |
| **Hestia** | Connections | dApp permissions management |
| **Olympus** | Domains | .shadow domain registration |
| **Plutus** | Portfolio | Portfolio tracking and history |
| **Hephaestus** | Caching | Content caching and optimization |
| **Artemis** | Rate Limiting | Request throttling |

---

## Key Features

### Decentralized Identity
- No usernames or passwords
- Cryptographic authentication via wallet signatures
- Full ownership of your identity

### Censorship-Resistant Content
- IPFS for mutable content storage
- Arweave for permanent, immutable storage
- Content addressed by hash (tamper-proof)

### Privacy & Security
- Client-side wallet encryption (AES-256-GCM)
- Optional Tor integration for IP masking
- Zero-knowledge architecture

### Token Economy
- Every URL maps to a unique SPL token
- Sites registered on-chain via Solana programs
- .shadow domain name system

---

## Quick Links

- [Running locally](running-locally.md)
- [Persistence decision](decisions/0001-postgres-on-supabase.md)

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Backend** | Rust + Actix-Web |
| **Frontend** | Next.js 15 + React |
| **Desktop** | Vue + Vite |
| **Mobile** | Flutter + Dart |
| **Blockchain** | Solana + Anchor |
| **Database** | MongoDB |
| **Storage** | IPFS (Pinata) + Arweave (Bundlr) |

---

## License

Shadow is open-source software. See the repository for license details.
