/**
 * Web Crypto API encryption utilities
 * Uses AES-GCM encryption with PBKDF2 key derivation
 */

/**
 * Derive encryption key from password using PBKDF2
 */
async function deriveKey(
  password: string,
  salt: Uint8Array,
  iterations: number = 100000
): Promise<CryptoKey> {
  const encoder = new TextEncoder()
  const passwordKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(password),
    'PBKDF2',
    false,
    ['deriveBits', 'deriveKey']
  )

  return crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt: salt,
      iterations: iterations,
      hash: 'SHA-256',
    },
    passwordKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  )
}

/**
 * Generate a random salt for key derivation
 */
export function generateSalt(): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(16))
}

/**
 * Encrypt data using AES-GCM
 */
export async function encrypt(
  data: Uint8Array,
  password: string,
  salt?: Uint8Array
): Promise<{ encrypted: ArrayBuffer; salt: Uint8Array; iv: Uint8Array }> {
  // Generate salt if not provided
  const encryptionSalt = salt || generateSalt()
  
  // Derive key from password
  const key = await deriveKey(password, encryptionSalt)
  
  // Generate IV (initialization vector)
  const iv = crypto.getRandomValues(new Uint8Array(12))
  
  // Encrypt data
  const encrypted = await crypto.subtle.encrypt(
    {
      name: 'AES-GCM',
      iv: iv,
    },
    key,
    data
  )
  
  return {
    encrypted,
    salt: encryptionSalt,
    iv,
  }
}

/**
 * Decrypt data using AES-GCM
 */
export async function decrypt(
  encrypted: ArrayBuffer,
  password: string,
  salt: Uint8Array,
  iv: Uint8Array
): Promise<Uint8Array> {
  // Derive key from password
  const key = await deriveKey(password, salt)
  
  // Decrypt data
  const decrypted = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: iv,
    },
    key,
    encrypted
  )
  
  return new Uint8Array(decrypted)
}

/**
 * Convert ArrayBuffer to base64 string for storage
 */
export function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}

/**
 * Convert base64 string to ArrayBuffer
 */
export function base64ToArrayBuffer(base64: string): ArrayBuffer {
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

/**
 * Convert Uint8Array to base64 string
 */
export function uint8ArrayToBase64(array: Uint8Array): string {
  return arrayBufferToBase64(array.buffer)
}

/**
 * Convert base64 string to Uint8Array
 */
export function base64ToUint8Array(base64: string): Uint8Array {
  return new Uint8Array(base64ToArrayBuffer(base64))
}





