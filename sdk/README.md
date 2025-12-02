# Hermes SDK

> Messenger of the gods - CLI tool and TypeScript SDK for building on Shadow.

Hermes, the messenger god, delivers your sites to the decentralized realm of Shadow. All developer tools are organized as **Circuits** - functions named after Greek gods.

## Installation

```bash
npm install -g hermes-sdk
# or
npm install hermes-sdk
```

## CLI Usage

### Initialize a new site

```bash
npx hermes-sdk init my-site
cd my-site
```

### Deploy a site

```bash
npx hermes-sdk deploy
```

### Options

- `--network <network>`: Network to deploy to (default: devnet)
- `--storage <storage>`: Storage provider - `ipfs` or `arweave` (default: ipfs)

## Circuits (Greek God Functions)

All SDK functions are organized as **Circuits** - named after Greek gods:

### 🏛️ **Olympus** - Domain Registration
Register contract addresses to domains (e.g., `whatsapp.shadow` → `WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump`)

```typescript
import { registerDomain, getDomain } from "hermes-sdk/circuits/olympus"

// Register domain
await registerDomain("whatsapp.shadow", contractAddress, walletPubkey, authHeader)

// Get domain
const domain = await getDomain("whatsapp.shadow")
```

### ⚡ **Zeus** - On-Chain Operations
Verify programs, check ownership, create transactions

```typescript
import { verifyProgram, getProgramData } from "hermes-sdk/circuits/zeus"

const exists = await verifyProgram(contractAddress)
```

### ☀️ **Apollo** - Validation
Validate inputs, sanitize strings, verify truth

```typescript
import { validateDomain, validatePubkey } from "hermes-sdk/circuits/apollo"

const isValid = validateDomain("whatsapp.shadow")
```

### ⚔️ **Ares** - Authentication
Create auth headers, sign challenges, verify signatures

```typescript
import { createAuthHeader } from "hermes-sdk/circuits/ares"

const authHeader = await createAuthHeader(wallet.publicKey, wallet)
```

### 🌊 **Poseidon** - Storage
Upload to IPFS/Arweave, retrieve content

```typescript
import { uploadToIPFS, uploadToArweave } from "hermes-sdk/circuits/poseidon"

const cid = await uploadToIPFS(file, "index.html")
```

### 🦉 **Athena** - Knowledge
Query profiles, search sites, get content

```typescript
import { getProfile, searchSites } from "hermes-sdk/circuits/athena"

const profile = await getProfile(walletAddress)
```

### 📨 **Hermes** - Messaging
WebSocket connections, real-time updates

```typescript
import { connectWebSocket, subscribeWallet } from "hermes-sdk/circuits/hermes"

const ws = connectWebSocket()
subscribeWallet(ws, walletAddress)
```

## Domain Registration Example

Register a contract address to a domain:

```typescript
import { registerDomain, verifyProgram, createAuthHeader } from "hermes-sdk"
import { Keypair } from "@solana/web3.js"

const wallet = Keypair.fromSecretKey(/* your secret key */)
const contractAddress = "WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump"

// Verify contract exists
const exists = await verifyProgram(contractAddress)
if (!exists) throw new Error("Contract not found")

// Create auth header
const authHeader = await createAuthHeader(wallet.publicKey, wallet)

// Register domain
const domain = await registerDomain(
  "whatsapp.shadow",
  contractAddress,
  wallet.publicKey.toBase58(),
  authHeader
)

console.log(`✅ Domain registered: ${domain.domain} → ${domain.program_address}`)
```

## Custom Domains

Shadow supports both `.shadow` domains and custom domains:

- ✅ `whatsapp.shadow` - Shadow TLD
- ✅ `example.com` - Custom domain
- ✅ `my-site.io` - Custom domain

## Environment Variables

- `SHADOW_BACKEND_URL`: Backend API URL (default: `http://localhost:8080`)
- `PINATA_API_KEY`: Pinata API key for IPFS storage
- `PINATA_SECRET`: Pinata secret for IPFS storage
- `BUNDLR_PRIVATE_KEY`: Bundlr private key for Arweave storage

## See Also

- [Circuit Examples](./EXAMPLES.md) - Detailed usage examples
- [Backend API](../backend/BACKEND_OVERVIEW.md) - Backend documentation
