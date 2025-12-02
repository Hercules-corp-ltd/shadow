// Zeus - God of Thunder and Power (On-Chain Operations Circuit)
// Handle Solana on-chain operations and program interactions

import { Connection, PublicKey, Keypair, Transaction } from "@solana/web3.js"
import { Program, AnchorProvider, Wallet } from "@coral-xyz/anchor"

const DEFAULT_RPC_URL = "https://api.devnet.solana.com"

/**
 * Verify a program address exists on-chain
 */
export async function verifyProgram(
  programAddress: string,
  rpcUrl: string = DEFAULT_RPC_URL
): Promise<boolean> {
  try {
    const connection = new Connection(rpcUrl, "confirmed")
    const pubkey = new PublicKey(programAddress)
    const accountInfo = await connection.getAccountInfo(pubkey)
    return accountInfo !== null && accountInfo.executable
  } catch {
    return false
  }
}

/**
 * Get program account data
 */
export async function getProgramData(
  programAddress: string,
  rpcUrl: string = DEFAULT_RPC_URL
): Promise<{ lamports: number; owner: string; dataLength: number } | null> {
  try {
    const connection = new Connection(rpcUrl, "confirmed")
    const pubkey = new PublicKey(programAddress)
    const accountInfo = await connection.getAccountInfo(pubkey)
    
    if (!accountInfo) return null
    
    return {
      lamports: accountInfo.lamports,
      owner: accountInfo.owner.toBase58(),
      dataLength: accountInfo.data.length,
    }
  } catch {
    return null
  }
}

/**
 * Verify wallet owns a program
 */
export async function verifyOwnership(
  programAddress: string,
  ownerPubkey: string,
  rpcUrl: string = DEFAULT_RPC_URL
): Promise<boolean> {
  try {
    const programData = await getProgramData(programAddress, rpcUrl)
    if (!programData) return false
    
    // Check if the owner matches
    // In production, you'd check the program's owner account
    return true // Simplified - implement actual ownership check
  } catch {
    return false
  }
}

/**
 * Create a transaction for on-chain operations
 */
export function createTransaction(
  instructions: any[],
  payer: PublicKey
): Transaction {
  const transaction = new Transaction()
  transaction.add(...instructions)
  transaction.feePayer = payer
  return transaction
}

