// Athena - Goddess of Wisdom (Knowledge Operations Circuit)
// Query and retrieve information from Shadow platform

import axios from "axios"

const BACKEND_URL = process.env.SHADOW_BACKEND_URL || "http://localhost:8080"

export interface Profile {
  wallet_pubkey: string
  profile_cid: string | null
  is_public: boolean
  exists: boolean
}

export interface Site {
  program_address: string
  owner_pubkey: string
  storage_cid: string
  name: string | null
  description: string | null
  created_at: string
  updated_at: string
}

/**
 * Get profile by wallet address
 */
export async function getProfile(wallet: string): Promise<Profile> {
  const response = await axios.get(`${BACKEND_URL}/api/profiles/${encodeURIComponent(wallet)}`)
  return response.data
}

/**
 * Search profiles
 */
export async function searchProfiles(query: string, limit: number = 10): Promise<Profile[]> {
  const response = await axios.get(
    `${BACKEND_URL}/api/profiles/search?q=${encodeURIComponent(query)}&limit=${limit}`
  )
  return response.data
}

/**
 * Get site by program address
 */
export async function getSite(programAddress: string): Promise<Site> {
  const response = await axios.get(
    `${BACKEND_URL}/api/sites/${encodeURIComponent(programAddress)}`
  )
  return response.data
}

/**
 * Search sites
 */
export async function searchSites(query: string, limit: number = 10): Promise<Site[]> {
  const response = await axios.get(
    `${BACKEND_URL}/api/sites/search?q=${encodeURIComponent(query)}&limit=${limit}`
  )
  return response.data
}

/**
 * Get site content
 */
export async function getSiteContent(programAddress: string): Promise<string> {
  const response = await axios.get(
    `${BACKEND_URL}/api/sites/${encodeURIComponent(programAddress)}/content`
  )
  return response.data
}


