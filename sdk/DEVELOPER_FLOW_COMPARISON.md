# Developer Flow: Current vs Desired Implementation

## Your Desired Flow

```
1. Setup: npx shadow-sdk init
   → Creates Anchor program template + off-chain assets

2. Build: Write Rust (on-chain) + React/HTML (off-chain)
   → Use Poseidon to upload assets

3. Deploy: npx shadow-sdk deploy
   → Compiles Rust program
   → Deploys to Solana (gets real program address)
   → Uploads assets to IPFS/Arweave
   → Optionally mints SPL token/NFT
   → Auto-registers .shadow domain

4. Launch: Site live at program address + .shadow alias
```

## Current Implementation

### ✅ What Works
- Basic `init` command (creates HTML template)
- Basic `deploy` command (uploads to IPFS/Arweave)
- SDK circuits exist (Olympus, Zeus, Apollo, Ares, Poseidon, Athena, Hermes)
- Domain registration API (backend)

### ❌ What's Missing
- `init` doesn't create Anchor program template
- `deploy` doesn't compile/deploy Solana programs
- `deploy` uses placeholder program address
- No domain auto-registration
- No SPL token/NFT minting
- No integration with Shadow Registry program

## Implementation Files

I've created two new files:

1. **`sdk/src/commands/init-full.ts`** - Enhanced init that creates:
   - Anchor program structure
   - Off-chain assets directory
   - React/HTML templates
   - Configuration files

2. **`sdk/src/commands/deploy-full.ts`** - Complete deployment flow:
   - Compiles Anchor program
   - Deploys to Solana (real program address)
   - Uploads assets via Poseidon
   - Mints SPL token/NFT (optional)
   - Registers domain via Olympus

## To Use the Full Flow

Update `sdk/src/cli.ts` to use the new commands:

```typescript
import { initFull } from "./commands/init-full"
import { deployFull } from "./commands/deploy-full"

// In init command:
await initFull(name || "my-site")

// In deploy command:
await deployFull(
  options.network,
  options.storage,
  options.domain,
  options.mintToken
)
```

## Next Steps

1. ✅ Code created (`init-full.ts`, `deploy-full.ts`)
2. ⚠️ Need to integrate into CLI
3. ⚠️ Need to test with actual Anchor programs
4. ⚠️ Need to connect to Shadow Registry program
5. ⚠️ Need to handle wallet management securely

## Dependencies Added

- `@solana/spl-token` - For token/NFT minting

