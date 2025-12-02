// Olympus - The Pantheon (Domain Registration Circuit)
// Register and manage domains for your Shadow sites

import axios from "axios"

const BACKEND_URL = process.env.SHADOW_BACKEND_URL || "http://localhost:8080"

export interface DomainRegistration {
  domain: string
  programAddress: string
  ownerPubkey: string
}

export interface Domain {
  domain: string
  owner_pubkey: string
  program_address: string
  verified: boolean
  created_at: string
  updated_at: string
}

/**
 * Register a domain to a contract/program address
 * Example: registerDomain("whatsapp.shadow", "WD3EtZGu8Gvhji4GHdLjGBfSc8cGSpyRJ612ANhpump", wallet)
 */
export async function registerDomain(
  domain: string,
  programAddress: string,
  ownerPubkey: string,
  authHeader?: string
): Promise<Domain> {
  const response = await axios.post(
    `${BACKEND_URL}/api/domains`,
    {
      domain,
      program_address: programAddress,
      owner_pubkey: ownerPubkey,
    },
    {
      headers: authHeader ? { "X-Shadow-Auth": authHeader } : {},
    }
  )

  return response.data
}

/**
 * Get domain information by domain name
 */
export async function getDomain(domain: string): Promise<Domain> {
  const response = await axios.get(`${BACKEND_URL}/api/domains/${encodeURIComponent(domain)}`)
  return response.data
}

/**
 * Get domain by program/contract address
 */
export async function getDomainByProgram(programAddress: string): Promise<Domain | null> {
  const response = await axios.get(
    `${BACKEND_URL}/api/domains/search?q=${encodeURIComponent(programAddress)}&limit=1`
  )
  const domains = response.data
  return domains.length > 0 ? domains[0] : null
}

/**
 * Update domain's program address
 */
export async function updateDomain(
  domain: string,
  programAddress: string,
  authHeader: string
): Promise<void> {
  await axios.put(
    `${BACKEND_URL}/api/domains/${encodeURIComponent(domain)}`,
    {
      program_address: programAddress,
    },
    {
      headers: { "X-Shadow-Auth": authHeader },
    }
  )
}

/**
 * Verify domain ownership (after on-chain verification)
 */
export async function verifyDomain(domain: string, authHeader: string): Promise<void> {
  await axios.post(
    `${BACKEND_URL}/api/domains/${encodeURIComponent(domain)}/verify`,
    {},
    {
      headers: { "X-Shadow-Auth": authHeader },
    }
  )
}

/**
 * List all domains owned by a wallet
 */
export async function listOwnerDomains(ownerPubkey: string): Promise<Domain[]> {
  const response = await axios.get(
    `${BACKEND_URL}/api/domains/owner/${encodeURIComponent(ownerPubkey)}`
  )
  return response.data
}

/**
 * Search domains
 */
export async function searchDomains(query: string, limit: number = 10): Promise<Domain[]> {
  const response = await axios.get(
    `${BACKEND_URL}/api/domains/search?q=${encodeURIComponent(query)}&limit=${limit}`
  )
  return response.data
}

