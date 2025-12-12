import { useState, useEffect } from "react"
import { useAuth } from "@/components/wallet-provider"
import { Button } from "@/components/ui/button"
import { ThemeToggle } from "@/components/theme-toggle"
import { shortenAddress } from "@/lib/utils"
import { hasStoredWallet } from "@/lib/wallet"
import { useNavigate } from "react-router-dom"

export default function Home() {
  const { isConnected, walletAddress, isLoading, createNewWallet, unlockWallet, logout } = useAuth()
  const navigate = useNavigate()

  return (
    <div className="min-h-screen bg-background">
      <div className="fixed top-4 right-4 z-30">
        <ThemeToggle />
      </div>

      <div className="container mx-auto px-4 py-16">
        <div className="text-center mb-12">
          <h1 className="text-5xl sm:text-6xl md:text-8xl font-bold mb-4">
            Shadow
          </h1>
          <p className="text-lg sm:text-xl md:text-2xl text-muted-foreground mb-8">
            You are whatever your wallet is. Forget who you are online.
          </p>

          {isLoading ? (
            <div className="text-muted-foreground">
              {hasStoredWallet() ? "Unlocking wallet..." : "Creating wallet..."}
            </div>
          ) : !isConnected ? (
            <div className="text-muted-foreground">
              Enter your password to continue
            </div>
          ) : (
            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <Button
                onClick={() => navigate("/profile/" + walletAddress)}
                variant="outline"
                size="lg"
              >
                My Profile
              </Button>
              {hasStoredWallet() && (
                <Button
                  onClick={unlockWallet}
                  variant="outline"
                  size="lg"
                >
                  Unlock Wallet
                </Button>
              )}
              <Button
                onClick={logout}
                variant="ghost"
                size="lg"
              >
                Delete Wallet
              </Button>
            </div>
          )}
        </div>

        {isConnected && walletAddress && (
          <div className="max-w-2xl mx-auto text-center">
            <p className="text-muted-foreground">
              Wallet: {shortenAddress(walletAddress)}
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
