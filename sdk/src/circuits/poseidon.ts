// Poseidon - God of the Sea (Storage Operations Circuit)
// Handle IPFS and Arweave storage operations

import axios from "axios"

const BACKEND_URL = process.env.SHADOW_BACKEND_URL || "http://localhost:8080"

/**
 * Upload file to IPFS via backend
 */
export async function uploadToIPFS(
  file: Buffer | Uint8Array,
  filename: string
): Promise<string> {
  const formData = new FormData()
  const blob = new Blob([file])
  formData.append("file", blob, filename)
  
  const response = await axios.post(`${BACKEND_URL}/api/upload/ipfs`, formData, {
    headers: {
      "Content-Type": "multipart/form-data",
    },
  })
  
  return response.data.cid
}

/**
 * Upload file to Arweave via backend
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
  
  return response.data.tx_id
}

/**
 * Get content from IPFS
 */
export async function getFromIPFS(cid: string): Promise<Buffer> {
  const cleanCid = cid.startsWith("ipfs://") ? cid.slice(7) : cid
  const response = await axios.get(
    `${BACKEND_URL}/api/sites/${cleanCid}/content`,
    {
      responseType: "arraybuffer",
    }
  )
  
  return Buffer.from(response.data)
}

/**
 * Get content from Arweave
 */
export async function getFromArweave(txId: string): Promise<Buffer> {
  const cleanTx = txId.startsWith("arweave://") ? txId.slice(10) : txId
  const response = await axios.get(
    `${BACKEND_URL}/api/sites/${cleanTx}/content`,
    {
      responseType: "arraybuffer",
    }
  )
  
  return Buffer.from(response.data)
}


