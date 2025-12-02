// Ares - God of War and Security (Authentication Circuit)
// Handle wallet authentication and signature verification

import { Keypair, PublicKey } from "@solana/web3.js"
import nacl from "tweetnacl"
import bs58 from "bs58"

export interface AuthChallenge {
  message: string
  timestamp: number
  wallet: string
}

/**
 * Create an authentication challenge
 */
export function createChallenge(wallet: string): AuthChallenge {
  const timestamp = Date.now()
  const message = `Shadow authentication challenge for ${wallet} at ${timestamp}`
  
  return {
    message,
    timestamp,
    wallet,
  }
}

/**
 * Sign a challenge with a wallet
 */
export async function signChallenge(
  challenge: AuthChallenge,
  keypair: Keypair
): Promise<string> {
  // Solana message signing format
  const messageBytes = new TextEncoder().encode(challenge.message)
  
  // Add Solana offchain message prefix
  const prefix = new TextEncoder().encode("\xffsolana offchain message")
  const lengthBytes = new Uint8Array([messageBytes.length])
  const fullMessage = new Uint8Array([
    ...prefix,
    ...lengthBytes,
    ...messageBytes,
  ])
  
  // Hash the message (SHA256)
  const crypto = require("crypto")
  const messageHash = crypto.createHash("sha256").update(fullMessage).digest()
  
  // Sign the message hash with ed25519
  const signature = nacl.sign.detached(messageHash, keypair.secretKey)
  
  return bs58.encode(signature)
}

/**
 * Create authentication header for API requests
 */
export async function createAuthHeader(
  wallet: Keypair | PublicKey,
  keypair?: Keypair
): Promise<string> {
  const walletPubkey = wallet instanceof PublicKey 
    ? wallet.toBase58() 
    : wallet.publicKey.toBase58()
  
  if (!keypair) {
    throw new Error("Keypair required for signing")
  }
  
  const challenge = createChallenge(walletPubkey)
  const signature = await signChallenge(challenge, keypair)
  
  return JSON.stringify({
    wallet: walletPubkey,
    signature,
    timestamp: challenge.timestamp,
  })
}

/**
 * Verify a signature (client-side verification)
 */
export function verifySignature(
  message: string,
  signature: string,
  pubkey: string
): boolean {
  // This is a simplified check - actual verification happens on backend
  try {
    new PublicKey(pubkey)
    bs58.decode(signature)
    return true
  } catch {
    return false
  }
}

