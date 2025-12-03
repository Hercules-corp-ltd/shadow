// Hermes - Messenger God (Communication Circuit)
// Handle WebSocket connections and real-time messaging

export interface HermesMessage {
  type: "subscribe" | "unsubscribe" | "ping"
  wallet?: string
  program?: string
}

export interface HermesResponse {
  type: "subscribed" | "unsubscribed" | "event" | "pong" | "error"
  topic?: string
  data?: any
  message?: string
}

/**
 * Connect to Shadow WebSocket
 */
export function connectWebSocket(url: string = "ws://localhost:8080/api/ws"): WebSocket {
  return new WebSocket(url)
}

/**
 * Subscribe to wallet events
 */
export function subscribeWallet(ws: WebSocket, wallet: string): void {
  const message: HermesMessage = {
    type: "subscribe",
    wallet,
  }
  ws.send(JSON.stringify(message))
}

/**
 * Subscribe to program events
 */
export function subscribeProgram(ws: WebSocket, program: string): void {
  const message: HermesMessage = {
    type: "subscribe",
    program,
  }
  ws.send(JSON.stringify(message))
}

/**
 * Unsubscribe from wallet events
 */
export function unsubscribeWallet(ws: WebSocket, wallet: string): void {
  const message: HermesMessage = {
    type: "unsubscribe",
    wallet,
  }
  ws.send(JSON.stringify(message))
}

/**
 * Unsubscribe from program events
 */
export function unsubscribeProgram(ws: WebSocket, program: string): void {
  const message: HermesMessage = {
    type: "unsubscribe",
    program,
  }
  ws.send(JSON.stringify(message))
}

/**
 * Send ping to keep connection alive
 */
export function ping(ws: WebSocket): void {
  const message: HermesMessage = {
    type: "ping",
  }
  ws.send(JSON.stringify(message))
}

/**
 * Parse WebSocket message
 */
export function parseMessage(data: string): HermesResponse {
  return JSON.parse(data)
}


