"use client"

import { useState, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { AppleSpotlight } from "@/components/ui/apple-spotlight"
import { useAuth } from "@/components/athena-provider"
import { Button } from "@/components/ui/button"
import { ThemeToggle } from "@/components/theme-toggle"
import { shortenAddress } from "@/lib/utils"
import { User, Globe, Upload, Settings } from "lucide-react"
import { useRouter } from "next/navigation"

interface SearchResult {
  id: string
  label: string
  icon: React.ReactNode
  link: string
  description: string
  type: "profile" | "site" | "shortcut"
}

async function search(query: string): Promise<SearchResult[]> {
  const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8080"
  const results: SearchResult[] = []

  try {
    // Token-only browser: Validate token address first
    const { parseTokenAddress } = await import("@/lib/token-validation")
    const parsed = parseTokenAddress(query.trim())
    
    if (parsed) {
      // Valid token address - navigate directly to token page
      const { tokenAddress, sublink } = parsed
      const subpath = sublink ? `/${sublink}` : ""
      results.push({
        id: `token-${tokenAddress}`,
        label: shortenAddress(tokenAddress) + (sublink ? `/${sublink}` : ""),
        icon: <Globe className="w-4 h-4" />,
        link: `/site/${tokenAddress}${subpath}`,
        description: sublink ? `Sublink: ${sublink}` : "Token address",
        type: "site" as const,
      })
      return results
    }

    // Fallback: Search profiles and sites (for partial matches)
    const profilesRes = await fetch(`${backendUrl}/api/profiles/search?q=${encodeURIComponent(query)}&limit=5`)
    if (profilesRes.ok) {
      const profiles = await profilesRes.json()
      results.push(...profiles.map((p: any) => ({
        id: `profile-${p.wallet_pubkey}`,
        label: shortenAddress(p.wallet_pubkey),
        icon: <User className="w-4 h-4" />,
        link: `/profile/${p.wallet_pubkey}`,
        description: p.is_public ? "Public profile" : "Anonymous profile",
        type: "profile" as const,
      })))
    }

    // Search Solana for token addresses
    const solanaRes = await fetch(`${backendUrl}/api/solana/search?q=${encodeURIComponent(query)}`)
    if (solanaRes.ok) {
      const solana = await solanaRes.json()
      if (solana.type === "program" || solana.type === "account") {
        results.push({
          id: `solana-${solana.data.address}`,
          label: shortenAddress(solana.data.address),
          icon: solana.type === "program" ? <Globe className="w-4 h-4" /> : <User className="w-4 h-4" />,
          link: solana.type === "program" ? `/site/${solana.data.address}` : `/profile/${solana.data.address}`,
          description: solana.type === "program" ? "Token/Site" : "Solana account",
          type: solana.type === "program" ? "site" : "profile",
        })
      }
    }
  } catch (error) {
    console.error("Search error:", error)
  }

  return results
}

export default function Home() {
  const { isConnected, walletAddress, login, logout } = useAuth()
  const [showWelcome, setShowWelcome] = useState(false)
  const router = useRouter()

  useEffect(() => {
    if (isConnected && walletAddress) {
      setShowWelcome(true)
      const timer = setTimeout(() => setShowWelcome(false), 5000)
      return () => clearTimeout(timer)
    }
  }, [isConnected, walletAddress])

  return (
    <div className="min-h-screen bg-gradient-to-br from-neutral-50 via-neutral-100 to-neutral-200 dark:from-neutral-950 dark:via-neutral-900 dark:to-neutral-800">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_50%,rgba(0,0,0,0.03),transparent)] dark:bg-[radial-gradient(circle_at_50%_50%,rgba(255,255,255,0.03),transparent)]" />
      
      <div className="fixed top-4 right-4 z-30">
        <ThemeToggle />
      </div>
      
      <AnimatePresence>
        {showWelcome && walletAddress && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="fixed top-4 left-1/2 -translate-x-1/2 z-50 bg-background/95 backdrop-blur-xl border border-border rounded-2xl shadow-xl p-6 max-w-md"
          >
            <motion.div
              initial={{ scale: 0.95 }}
              animate={{ scale: 1 }}
              transition={{ type: "spring", stiffness: 300 }}
            >
              <h2 className="text-2xl font-bold mb-2">Welcome, {shortenAddress(walletAddress)}</h2>
              <p className="text-muted-foreground mb-2">
                You're whatever your wallet is — forget who you are online.
              </p>
              <p className="text-sm text-muted-foreground">
                Even Shadow doesn't know or store your Gmail.
              </p>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="relative z-10 container mx-auto px-4 py-16">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="text-center mb-12"
        >
          <motion.h1
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
            className="text-6xl md:text-8xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-foreground to-muted-foreground"
          >
            Shadow
          </motion.h1>
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4 }}
            className="text-xl md:text-2xl text-muted-foreground mb-8"
          >
            You are whatever your wallet is. Forget who you are online.
          </motion.p>

          {!isConnected ? (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.6 }}
            >
              <Button
                onClick={() => login()}
                size="lg"
                className="text-lg px-8 py-6 rounded-xl"
              >
                Create Athena Wallet
              </Button>
            </motion.div>
          ) : (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.6 }}
              className="flex items-center justify-center gap-4"
            >
              <Button
                onClick={() => router.push("/profile/" + walletAddress)}
                variant="outline"
                size="lg"
              >
                My Profile
              </Button>
              <Button
                onClick={logout}
                variant="ghost"
                size="lg"
              >
                Disconnect
              </Button>
            </motion.div>
          )}
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.8 }}
          className="max-w-2xl mx-auto"
        >
          <AppleSpotlight onSearch={search} />
        </motion.div>
      </div>
    </div>
  )
}

