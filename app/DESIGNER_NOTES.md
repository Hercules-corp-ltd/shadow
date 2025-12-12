# Designer Notes - Shadow Browser Web App

## Overview
This is the **web version** of Shadow Browser (React + Vite). The mobile app uses Flutter and desktop uses Vue - see those directories for their respective implementations.

## Current Structure

### Core Components (Keep These)
- `src/components/wallet-provider.tsx` - Wallet state management (required)
- `src/components/password-dialog.tsx` - Password input for wallet encryption (required)
- `src/components/theme-provider.tsx` - Dark/light theme support
- `src/components/theme-toggle.tsx` - Theme switcher button
- `src/components/ui/button.tsx` - Reusable button component
- `src/components/ui/dialog.tsx` - Dialog/modal component
- `src/components/ui/input.tsx` - Input field component

### Pages (Simplify/Redesign)
- `src/pages/Home.tsx` - Main landing page (currently minimal, ready for design)
- `src/pages/ProfilePage.tsx` - Profile view page (basic layout, needs design)
- `src/pages/SitePage.tsx` - Site/content view page (basic layout, needs design)

### Core Logic (Don't Touch)
- `src/lib/wallet.ts` - Wallet encryption/decryption (AES-GCM)
- `src/lib/crypto.ts` - Web Crypto API utilities
- `src/lib/utils.ts` - Utility functions

## Removed/Simplified
- ❌ Removed: `apple-spotlight.tsx` (complex search component)
- ❌ Removed: `verify-storage.ts` (test file)
- ❌ Removed: `wallet-storage-test.ts` (test file)
- ❌ Removed: Complex animations (framer-motion)
- ❌ Removed: Tauri/Capacitor dependencies (using Flutter/Vue instead)
- ❌ Removed: Unused dependencies (zustand, react-use, etc.)

## Design Guidelines

### Wallet Flow
1. User opens app → checks if wallet exists
2. If no wallet → show "Create Wallet" button → password dialog
3. If wallet exists → show "Unlock Wallet" button → password dialog
4. After unlock → show wallet address and navigation

### Key Features to Design
1. **Home Page**: 
   - Clean landing with wallet status
   - Navigation to profile/sites
   - Theme toggle (top right)

2. **Profile Page**:
   - Display wallet address
   - Show profile info if public
   - Back button

3. **Site Page**:
   - Display site content (HTML from backend)
   - Site metadata
   - Back button

### Styling
- Uses Tailwind CSS
- Dark/light theme support via `next-themes`
- Color scheme defined in `tailwind.config.ts`
- Components use shadcn/ui patterns

### Backend Integration
- Backend URL: `VITE_BACKEND_URL` env var or `http://localhost:8080`
- API endpoints:
  - `/api/profiles/:wallet` - Get profile
  - `/api/sites/:program` - Get site
  - `/api/sites/:program/content` - Get site HTML content

## What You Can Change
✅ All styling and layout
✅ Component structure (keep functionality)
✅ Add new UI components
✅ Redesign pages completely
✅ Add animations (but keep it simple)
✅ Change color schemes
✅ Add new pages/routes

## What You Shouldn't Change
❌ `wallet.ts` - Core wallet encryption logic
❌ `crypto.ts` - Encryption utilities
❌ `wallet-provider.tsx` - Wallet state management logic
❌ Password dialog functionality
❌ API endpoint calls (unless backend changes)

## Getting Started
```bash
cd app
npm install
npm run dev
```

The app will run on `http://localhost:5173` (Vite default).

## Notes for Designer
- Keep the wallet flow intact (create/unlock/logout)
- Maintain theme support (dark/light)
- Ensure responsive design (mobile/tablet/desktop)
- Keep accessibility in mind
- The wallet address should be clearly visible when connected
- Password dialogs should be secure and user-friendly

