// Apollo - God of Truth and Light (Validation Circuit)
// Validate inputs and verify truth

/**
 * Validate a Solana public key
 */
export function validatePubkey(pubkey: string): boolean {
  try {
    new (require("@solana/web3.js").PublicKey)(pubkey)
    return true
  } catch {
    return false
  }
}

/**
 * Validate domain name format
 */
export function validateDomain(domain: string): boolean {
  if (!domain || domain.length === 0) return false
  if (domain.length > 253) return false

  // Check if it's a .shadow domain
  if (domain.endsWith(".shadow")) {
    const name = domain.slice(0, -7) // Remove ".shadow"
    if (name.length === 0 || name.length > 63) return false
    return /^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/i.test(name)
  }

  // Custom domain validation
  const parts = domain.split(".")
  if (parts.length < 2) return false

  for (const part of parts) {
    if (part.length === 0 || part.length > 63) return false
    if (!/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/i.test(part)) return false
  }

  return true
}

/**
 * Validate IPFS CID
 */
export function validateIPFSCid(cid: string): boolean {
  if (!cid || cid.length === 0) return false
  
  const cleanCid = cid.startsWith("ipfs://") ? cid.slice(7) : cid
  return cleanCid.length >= 10 && cleanCid.length <= 100
}

/**
 * Validate Arweave transaction ID
 */
export function validateArweaveTx(txId: string): boolean {
  if (!txId || txId.length === 0) return false
  
  const cleanTx = txId.startsWith("arweave://") ? txId.slice(10) : txId
  return cleanTx.length >= 20 && cleanTx.length <= 100
}

/**
 * Sanitize string input
 */
export function sanitizeString(input: string, maxLength: number = 1000): string {
  if (input.length > maxLength) {
    throw new Error(`String too long (max ${maxLength} characters)`)
  }
  
  // Remove control characters except newline, carriage return, tab
  return input
    .split("")
    .filter((c) => {
      const code = c.charCodeAt(0)
      return code >= 32 || code === 9 || code === 10 || code === 13
    })
    .join("")
}


