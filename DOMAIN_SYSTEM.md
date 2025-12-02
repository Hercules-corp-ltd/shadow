# Shadow Domain System - Olympus CA

## Overview

The Shadow domain system allows developers to register Solana contract/program addresses to human-readable domains. This enables users to access sites using memorable names instead of long contract addresses.

## Example

```
whatsapp.shadow → WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump
```

## Domain Types

### 1. Shadow TLD Domains (`.shadow`)
- Format: `{name}.shadow`
- Examples: `whatsapp.shadow`, `my-site.shadow`
- Validation: Alphanumeric + hyphens, max 63 chars

### 2. Custom Domains
- Format: Any valid domain format
- Examples: `example.com`, `my-site.io`, `app.network`
- Validation: Standard domain format rules

## Backend Implementation

### Olympus Module (`backend/src/olympus.rs`)

**Functions:**
- `register_domain()` - Register a domain to a contract address
- `get_domain()` - Get domain by name
- `get_domain_by_program()` - Get domain by contract address
- `verify_domain()` - Mark domain as verified (after on-chain verification)
- `transfer_domain()` - Transfer domain ownership
- `list_owner_domains()` - List all domains owned by a wallet
- `search_domains()` - Search domains by name or contract address

### API Endpoints

```
POST   /api/domains              - Register domain
GET    /api/domains/{domain}      - Get domain info
GET    /api/domains/search        - Search domains
PUT    /api/domains/{domain}      - Update domain
POST   /api/domains/{domain}/verify - Verify domain
GET    /api/domains/owner/{wallet} - List owner domains
```

### Database Schema

```rust
{
  _id: String,                    // Domain name
  owner_pubkey: String,           // Wallet that owns the domain
  program_address: String,        // Solana contract/program address
  verified: bool,                 // On-chain verification status
  created_at: DateTime,
  updated_at: DateTime,
  expires_at: Option<DateTime>
}
```

## SDK Circuits (Greek God Functions)

### 🏛️ Olympus Circuit - Domain Registration

```typescript
import { registerDomain, getDomain } from "hermes-sdk/circuits/olympus"

// Register domain
await registerDomain(
  "whatsapp.shadow",
  "WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump",
  walletPubkey,
  authHeader
)

// Get domain
const domain = await getDomain("whatsapp.shadow")
```

### ⚡ Zeus Circuit - On-Chain Verification

```typescript
import { verifyProgram } from "hermes-sdk/circuits/zeus"

// Verify contract exists on-chain
const exists = await verifyProgram(contractAddress)
```

### ☀️ Apollo Circuit - Validation

```typescript
import { validateDomain } from "hermes-sdk/circuits/apollo"

// Validate domain format
const isValid = validateDomain("whatsapp.shadow")
```

## Usage Flow

### 1. Developer Deploys Contract
```typescript
// Deploy Solana program
const programAddress = "WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump"
```

### 2. Verify Contract Exists
```typescript
import { verifyProgram } from "hermes-sdk/circuits/zeus"

const exists = await verifyProgram(programAddress)
if (!exists) throw new Error("Contract not found")
```

### 3. Register Domain
```typescript
import { registerDomain, createAuthHeader } from "hermes-sdk"
import { Keypair } from "@solana/web3.js"

const wallet = Keypair.fromSecretKey(/* secret key */)
const authHeader = await createAuthHeader(wallet.publicKey, wallet)

const domain = await registerDomain(
  "whatsapp.shadow",
  programAddress,
  wallet.publicKey.toBase58(),
  authHeader
)
```

### 4. Verify Domain (After On-Chain Verification)
```typescript
import { verifyDomain } from "hermes-sdk/circuits/olympus"

await verifyDomain("whatsapp.shadow", authHeader)
```

## Authentication

All domain registration/updates require wallet signature authentication:

1. Client creates challenge: `"Shadow authentication challenge for {wallet} at {timestamp}"`
2. Client signs challenge with wallet
3. Client sends auth header: `X-Shadow-Auth: {"wallet":"...","signature":"...","timestamp":...}`
4. Backend verifies signature and ownership

## Security

- ✅ Domain ownership verified via wallet signature
- ✅ Contract address validated on-chain
- ✅ Domain format validated (Apollo circuit)
- ✅ Rate limiting (Artemis circuit)
- ✅ Input sanitization

## All SDK Circuits

| Circuit | God | Purpose |
|---------|-----|---------|
| **Olympus** | Pantheon | Domain registration |
| **Zeus** | Thunder | On-chain operations |
| **Apollo** | Truth | Validation |
| **Ares** | War | Authentication |
| **Poseidon** | Sea | Storage (IPFS/Arweave) |
| **Athena** | Wisdom | Knowledge/Queries |
| **Hermes** | Messenger | WebSocket/Real-time |

## Examples

See `sdk/EXAMPLES.md` for complete usage examples.

