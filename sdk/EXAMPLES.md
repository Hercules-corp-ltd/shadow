# Hermes SDK - Circuit Examples

> Greek God Functions for Shadow Development

## Olympus Circuit - Domain Registration

Register a contract address to a domain:

```typescript
import { registerDomain, getDomain } from "hermes-sdk/circuits/olympus"
import { createAuthHeader } from "hermes-sdk/circuits/ares"
import { Keypair } from "@solana/web3.js"

// Example: Register whatsapp.shadow to a contract address
const wallet = Keypair.fromSecretKey(/* your secret key */)
const contractAddress = "WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump"
const domain = "whatsapp.shadow"

// Create authentication header
const authHeader = await createAuthHeader(wallet.publicKey, wallet)

// Register the domain
const domainData = await registerDomain(
  domain,
  contractAddress,
  wallet.publicKey.toBase58(),
  authHeader
)

console.log(`Domain registered: ${domainData.domain} -> ${domainData.program_address}`)

// Get domain information
const domainInfo = await getDomain("whatsapp.shadow")
console.log(domainInfo)
```

## Zeus Circuit - On-Chain Verification

Verify a program exists on-chain:

```typescript
import { verifyProgram, getProgramData } from "hermes-sdk/circuits/zeus"

const contractAddress = "WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump"

// Verify program exists
const exists = await verifyProgram(contractAddress)
console.log(`Program exists: ${exists}`)

// Get program data
const programData = await getProgramData(contractAddress)
if (programData) {
  console.log(`Owner: ${programData.owner}`)
  console.log(`Data length: ${programData.dataLength}`)
}
```

## Apollo Circuit - Validation

Validate inputs before operations:

```typescript
import { validateDomain, validatePubkey, sanitizeString } from "hermes-sdk/circuits/apollo"

// Validate domain
const isValid = validateDomain("whatsapp.shadow")
console.log(`Domain valid: ${isValid}`)

// Validate Solana pubkey
const isValidPubkey = validatePubkey("WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump")
console.log(`Pubkey valid: ${isValidPubkey}`)

// Sanitize user input
const clean = sanitizeString("user input<script>alert('xss')</script>", 1000)
```

## Ares Circuit - Authentication

Create authentication headers for API requests:

```typescript
import { createAuthHeader, createChallenge, signChallenge } from "hermes-sdk/circuits/ares"
import { Keypair } from "@solana/web3.js"

const wallet = Keypair.fromSecretKey(/* your secret key */)

// Create auth header for API requests
const authHeader = await createAuthHeader(wallet.publicKey, wallet)
console.log(authHeader) // JSON string with wallet, signature, timestamp

// Or manually create challenge and sign
const challenge = createChallenge(wallet.publicKey.toBase58())
const signature = await signChallenge(challenge, wallet)
```

## Poseidon Circuit - Storage

Upload and retrieve files from IPFS/Arweave:

```typescript
import { uploadToIPFS, uploadToArweave, getFromIPFS } from "hermes-sdk/circuits/poseidon"
import * as fs from "fs"

// Upload to IPFS
const file = fs.readFileSync("index.html")
const cid = await uploadToIPFS(file, "index.html")
console.log(`Uploaded to IPFS: ${cid}`)

// Upload to Arweave
const txId = await uploadToArweave(file, "index.html")
console.log(`Uploaded to Arweave: ${txId}`)

// Retrieve from IPFS
const content = await getFromIPFS(cid)
console.log(content.toString())
```

## Athena Circuit - Knowledge

Query profiles and sites:

```typescript
import { getProfile, searchSites, getSiteContent } from "hermes-sdk/circuits/athena"

// Get profile
const profile = await getProfile("WalletAddress...")
console.log(profile)

// Search sites
const sites = await searchSites("whatsapp", 10)
console.log(sites)

// Get site content
const content = await getSiteContent("ProgramAddress...")
console.log(content)
```

## Hermes Circuit - Real-Time

Connect to WebSocket for real-time updates:

```typescript
import {
  connectWebSocket,
  subscribeWallet,
  subscribeProgram,
  parseMessage
} from "hermes-sdk/circuits/hermes"

// Connect to WebSocket
const ws = connectWebSocket("ws://localhost:8080/api/ws")

ws.onopen = () => {
  console.log("Connected to Shadow WebSocket")
  
  // Subscribe to wallet events
  subscribeWallet(ws, "WalletAddress...")
  
  // Subscribe to program events
  subscribeProgram(ws, "ProgramAddress...")
}

ws.onmessage = (event) => {
  const response = parseMessage(event.data)
  console.log("Received:", response)
  
  if (response.type === "event") {
    console.log(`Event on ${response.topic}:`, response.data)
  }
}
```

## Complete Example: Register Domain for Site

```typescript
import { Keypair } from "@solana/web3.js"
import {
  registerDomain,
  verifyProgram,
  createAuthHeader,
  uploadToIPFS
} from "hermes-sdk"

async function deploySite() {
  const wallet = Keypair.fromSecretKey(/* your secret key */)
  const contractAddress = "WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump"
  
  // 1. Verify contract exists on-chain
  const exists = await verifyProgram(contractAddress)
  if (!exists) {
    throw new Error("Contract does not exist on-chain")
  }
  
  // 2. Upload site content
  const file = fs.readFileSync("dist/index.html")
  const cid = await uploadToIPFS(file, "index.html")
  
  // 3. Register domain
  const authHeader = await createAuthHeader(wallet.publicKey, wallet)
  const domain = await registerDomain(
    "whatsapp.shadow",
    contractAddress,
    wallet.publicKey.toBase58(),
    authHeader
  )
  
  console.log(`✅ Site deployed!`)
  console.log(`   Domain: ${domain.domain}`)
  console.log(`   Contract: ${domain.program_address}`)
  console.log(`   Storage: ${cid}`)
}
```


