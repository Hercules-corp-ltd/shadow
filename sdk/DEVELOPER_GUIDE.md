# Shadow Developer Guide 🏛️

> Build decentralized sites/apps for the Shadow browser

## Quick Start

```bash
# Install SDK
npm install -g shadow-sdk

# Initialize new site
npx shadow-sdk init my-site
cd my-site

# Build Solana program
anchor build

# Deploy (compiles program, uploads assets, registers domain)
npx shadow-sdk deploy --domain my-site.shadow
```

## Complete Developer Flow

### 1. Setup (`npx shadow-sdk init`)

Creates:
- ✅ Anchor program structure (`programs/`)
- ✅ Off-chain assets directory (`assets/`)
- ✅ HTML/React templates
- ✅ Configuration (`shadow.json`)

**Structure:**
```
my-site/
├── programs/
│   └── my-site/
│       └── src/
│           └── lib.rs      # Solana program (Rust)
├── assets/
│   └── index.html          # Frontend content
├── shadow.json             # Configuration
└── Anchor.toml            # Anchor config
```

### 2. Build Your Site

#### On-Chain (Rust/Anchor)
Edit `programs/my-site/src/lib.rs`:
```rust
use anchor_lang::prelude::*;

declare_id!("YOUR_PROGRAM_ID");

#[program]
pub mod my_site {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Site initialized!");
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
```

#### Off-Chain (HTML/React)
Edit `assets/index.html` or create React components in `assets/`.

### 3. Deploy (`npx shadow-sdk deploy`)

The deploy command does:

1. **Compiles** Anchor program
2. **Deploys** to Solana (gets real program address)
3. **Uploads** assets to IPFS/Arweave
4. **Optionally mints** SPL token/NFT
5. **Registers** `.shadow` domain

**Options:**
```bash
# Basic deployment
npx shadow-sdk deploy

# With domain
npx shadow-sdk deploy --domain mysite.shadow

# With token minting
npx shadow-sdk deploy --mint-token

# Full deployment
npx shadow-sdk deploy \
  --domain mysite.shadow \
  --mint-token \
  --network devnet \
  --storage ipfs
```

### 4. Launch

Your site is now live at:
- **Program Address**: `9xY...zA1` (Solana address)
- **Domain**: `mysite.shadow` (if registered)

Users can access via:
- Shadow browser Spotlight search
- Direct program address
- `.shadow` domain

## SDK Circuits (Greek God Functions)

### 🏛️ Olympus - Domain Registration
```typescript
import { registerDomain } from "shadow-sdk/circuits/olympus"

await registerDomain(
  "mysite.shadow",
  programAddress,
  walletPubkey,
  authHeader
)
```

### ⚡ Zeus - On-Chain Operations
```typescript
import { verifyProgram, mintSiteToken } from "shadow-sdk/circuits/zeus"

// Verify program exists
const exists = await verifyProgram(programAddress)

// Mint token (in deploy-full.ts)
const token = await mintSiteToken(programId, wallet, connection)
```

### ☀️ Apollo - Validation
```typescript
import { validateDomain, validatePubkey } from "shadow-sdk/circuits/apollo"

const isValid = validateDomain("mysite.shadow")
```

### 🌊 Poseidon - Storage
```typescript
import { uploadToIPFS, uploadToArweave } from "shadow-sdk/circuits/poseidon"

const cid = await uploadToIPFS(file, "index.html")
```

### ⚔️ Ares - Authentication
```typescript
import { createAuthHeader } from "shadow-sdk/circuits/ares"

const authHeader = await createAuthHeader(wallet.publicKey, wallet)
```

## Token Launch (Optional)

When deploying with `--mint-token`, the SDK:
1. Creates SPL token mint
2. Mints 1 token (NFT) to your wallet
3. Token represents site ownership
4. Can be traded on Solana DEXes

**Use Cases:**
- Site ownership/shares
- Revenue sharing
- Governance tokens
- Access tokens

## Configuration (`shadow.json`)

```json
{
  "name": "my-site",
  "version": "0.1.0",
  "storage": "ipfs",
  "network": "devnet",
  "programPath": "./programs",
  "domain": "mysite.shadow",
  "mintToken": false
}
```

## Environment Variables

```bash
# Storage
PINATA_API_KEY=your_key
PINATA_SECRET=your_secret
BUNDLR_PRIVATE_KEY=your_key

# Backend
SHADOW_BACKEND_URL=http://localhost:8080

# Solana
SOLANA_RPC_URL=https://api.devnet.solana.com
```

## Examples

### Basic Site
```bash
npx shadow-sdk init blog
cd blog
# Edit assets/index.html
anchor build
npx shadow-sdk deploy --domain blog.shadow
```

### Tokenized App
```bash
npx shadow-sdk init myapp
cd myapp
# Write Solana program logic
anchor build
npx shadow-sdk deploy \
  --domain myapp.shadow \
  --mint-token
```

### Custom Domain
```bash
npx shadow-sdk deploy --domain example.com
```

## Troubleshooting

**"Anchor.toml not found"**
- Run `anchor init` first, or use `--basic` flag

**"Program deployment failed"**
- Check Solana wallet has SOL
- Verify network (devnet/mainnet)
- Check Anchor installation

**"Domain registration failed"**
- Verify domain format (must end with `.shadow` or be valid domain)
- Check authentication (wallet signature)
- Ensure backend is running

## Next Steps

- Connect to Shadow Registry program (on-chain domain verification)
- Add site templates
- Add analytics
- Add monetization features

See `DEVELOPER_FLOW_COMPARISON.md` for implementation details.

