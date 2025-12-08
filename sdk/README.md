# Hermes SDK 🏛️

> Messenger of the gods - Convert any site to work with Shadow browser

Hermes delivers your sites to the decentralized realm of Shadow. Install this SDK to convert your existing website into a Shadow-compatible site that uses **contract addresses** and **tokens** instead of traditional domains.

## Installation

```bash
npm install -g shadow-sdk
# or
npm install shadow-sdk
```

## Quick Start: Convert Your Existing Site

The easiest way to get started - convert your existing site to work with Shadow:

```bash
# Navigate to your existing site
cd my-website

# Convert to Shadow format
npx shadow-sdk convert

# That's it! Your site now works with Shadow browser
```

This will:
- ✅ Upload your site assets to IPFS/Arweave
- ✅ Mint a site token (used as your "domain")
- ✅ Register the token address for Shadow browser
- ✅ Create `shadow.json` config file
- ✅ Generate `shadow-integration.js` for your site

## How It Works

### Traditional Web
```
https://example.com → DNS lookup → Server
```

### Shadow Browser
```
Contract Address (Token) → On-chain lookup → IPFS/Arweave
```

Your site gets:
- **Contract Address**: Solana program/token address (e.g., `9xY...zA1`)
- **Site Token**: SPL token that represents your site (used as domain)
- **Decentralized Storage**: Assets stored on IPFS/Arweave
- **No DNS**: Everything resolved on-chain

## Commands

### Convert Existing Site
```bash
npx shadow-sdk convert [path]
```

Options:
- `--network <network>` - Network (devnet|mainnet-beta)
- `--storage <storage>` - Storage provider (ipfs|arweave)
- `--no-mint-token` - Skip token minting

### Initialize New Shadow Site
```bash
npx shadow-sdk init my-site
```

Creates a new Shadow site with Anchor program structure.

### Deploy Site
```bash
npx shadow-sdk deploy
```

Deploys your site (compiles program, uploads assets, registers domain).

## Site Token as Domain

When you convert a site, a **site token** is minted. This token:

1. **Acts as your domain** - Users can access your site via the token address
2. **Represents ownership** - You own the token, you own the site
3. **Tradable** - Can be sold/transferred on Solana DEXes
4. **Unique identifier** - Each site gets a unique token

Example:
```javascript
// Your site token address becomes your "domain"
const siteToken = "9xYzA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0"
// Shadow browser resolves: siteToken → IPFS content
```

## Integration

After converting, import the integration file:

```javascript
// In your site code
import { getShadowAddress, getShadowDomain } from './shadow-integration.js'

// Use in your app
const shadowAddress = getShadowAddress()
const shadowDomain = getShadowDomain()
```

## Configuration

After conversion, `shadow.json` is created:

```json
{
  "name": "my-site",
  "version": "1.0.0",
  "storage": "ipfs",
  "network": "devnet",
  "storageCid": "ipfs://Qm...",
  "programAddress": "9xY...zA1",
  "tokenMint": "9xY...zA1",
  "domain": "9xYzA1B2.shadow",
  "converted": true
}
```

## Examples

### Convert React App
```bash
cd my-react-app
npx shadow-sdk convert
# Site is now Shadow-compatible!
```

### Convert Next.js Site
```bash
cd my-nextjs-site
npx shadow-sdk convert --storage ipfs
# Deploy normally, Shadow browser will use contract address
```

### Convert Static Site
```bash
cd my-static-site
npx shadow-sdk convert --network devnet
# Assets uploaded, token minted, ready for Shadow!
```

## How Shadow Browser Works

1. **User enters contract address** in Shadow browser
2. **Browser queries on-chain** for site metadata
3. **Resolves to IPFS/Arweave** content
4. **Renders site** using contract address as identifier

No DNS, no central servers - everything decentralized!

## Circuits (Greek God Functions)

All SDK functions are organized as **Circuits** - named after Greek gods:

- 🏛️ **Olympus** - Domain registration
- ⚡ **Zeus** - On-chain operations
- ☀️ **Apollo** - Validation
- 🌊 **Poseidon** - Storage (IPFS/Arweave)
- ⚔️ **Ares** - Authentication
- 🦉 **Athena** - Wisdom & utilities
- 🚀 **Hermes** - Messaging & WebSocket

## Requirements

- Node.js 18+
- Solana CLI (for deployments)
- Backend running (for uploads/registration)

## Environment Variables

```bash
# Storage (optional - uses backend by default)
PINATA_API_KEY=your_key
PINATA_SECRET=your_secret
BUNDLR_PRIVATE_KEY=your_key

# Backend
SHADOW_BACKEND_URL=http://localhost:8080

# Solana
SOLANA_RPC_URL=https://api.devnet.solana.com
```

## Learn More

- [Developer Guide](./DEVELOPER_GUIDE.md)
- [Status Report](./STATUS.md)
- [Examples](./EXAMPLES.md)

---

**Built on Shadow** - Decentralized web, powered by Solana 🚀
