# Shadow Browser - Web App (React)

This is the **web version** of Shadow Browser built with React + Vite + TypeScript.

> **Note**: Mobile app uses Flutter (`mobile/`) and desktop app uses Vue (`desktop/`).

## Quick Start

```bash
npm install
npm run dev
```

## Structure

- `src/pages/` - Main pages (Home, Profile, Site)
- `src/components/` - Reusable components
- `src/lib/` - Core wallet and crypto logic

## For Designers

The web app is themed through CSS variables in the component layer. Wallet generation, encryption, and Solana address handling in `src/lib/` should stay intact when restyling.

## Features

- ✅ Solana wallet generation & encryption
- ✅ AES-GCM encryption (256-bit)
- ✅ Password-protected storage
- ✅ Dark/light theme support
- ✅ Responsive design

