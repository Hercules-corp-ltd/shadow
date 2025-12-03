# Developer Flow - Current vs Desired

## Current Implementation Status

### ✅ What's Implemented
- ✅ `init` command - Creates basic HTML template
- ✅ `deploy` command - Uploads files to IPFS/Arweave
- ✅ SDK circuits (Olympus, Zeus, Apollo, Ares, Poseidon, Athena, Hermes)
- ✅ Domain registration API (backend)
- ✅ Storage upload functions

### ❌ What's Missing
- ❌ `init` doesn't create Anchor program template
- ❌ `deploy` doesn't actually deploy Solana programs
- ❌ `deploy` uses placeholder program address
- ❌ No domain auto-registration after deploy
- ❌ No SPL token/NFT minting
- ❌ No integration with Shadow Registry program

## Desired Flow (Your Description)

1. **Setup**: `npx shadow-sdk init` → Creates Anchor program + off-chain assets
2. **Build**: Write Rust (on-chain) + React/HTML (off-chain)
3. **Deploy**: `npx shadow-sdk deploy` → 
   - Compiles Rust program
   - Deploys to Solana (gets real program address)
   - Uploads assets to IPFS/Arweave
   - Optionally mints SPL token/NFT
   - Auto-registers `.shadow` domain
4. **Launch**: Site live at program address + `.shadow` alias

## Implementation Plan

See `sdk/src/commands/deploy-full.ts` for the complete implementation.


