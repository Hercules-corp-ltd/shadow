// Poseidon - Node.js compatible version (for CLI)
// Handle IPFS and Arweave storage operations in Node.js environment

import axios from "axios"
import FormData from "form-data"
import * as fs from "fs"

const BACKEND_URL = process.env.SHADOW_BACKEND_URL || "http://localhost:8080"

/**
 * Upload file to IPFS via backend (Node.js compatible)
 */
export async function uploadToIPFS(
  file: Buffer | Uint8Array,
  filename: string
): Promise<string> {
  const formData = new FormData()
  formData.append("file", file, filename)
  
  const response = await axios.post(`${BACKEND_URL}/api/upload/ipfs`, formData, {
    headers: {
      ...formData.getHeaders(),
    },
  })
  
  return response.data.cid || response.data.ipfs_hash || `ipfs://${response.data.IpfsHash}`
}

/**
 * Upload file to Arweave via backend (Node.js compatible)
 */
export async function uploadToArweave(
  file: Buffer | Uint8Array,
  filename: string
): Promise<string> {
  const response = await axios.post(
    `${BACKEND_URL}/api/upload/arweave`,
    file,
    {
      headers: {
        "Content-Type": "application/octet-stream",
      },
    }
  )
  
  return response.data.tx_id || response.data.id || `arweave://${response.data.id}`
}

/**
 * Upload multiple files to IPFS (directory)
 */
export async function uploadDirectoryToIPFS(
  files: Array<{ path: string; content: Buffer }>
): Promise<string> {
  const formData = new FormData()
  
  for (const file of files) {
    formData.append("files", file.content, {
      filename: file.path,
    })
  }
  
  const response = await axios.post(`${BACKEND_URL}/api/upload/ipfs/directory`, formData, {
    headers: {
      ...formData.getHeaders(),
    },
  })
  
  return response.data.cid || `ipfs://${response.data.IpfsHash}`
}


