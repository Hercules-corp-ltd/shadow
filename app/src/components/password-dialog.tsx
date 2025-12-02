import * as React from "react"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { AlertCircle, Lock } from "lucide-react"

interface PasswordDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  onConfirm: (password: string) => Promise<void>
  title?: string
  description?: string
  confirmText?: string
  isNewWallet?: boolean
  error?: string | null
}

export function PasswordDialog({
  open,
  onOpenChange,
  onConfirm,
  title = "Enter Password",
  description = "Enter your encryption password to access your wallet",
  confirmText = "Confirm",
  isNewWallet = false,
  error,
}: PasswordDialogProps) {
  const [password, setPassword] = React.useState("")
  const [confirmPassword, setConfirmPassword] = React.useState("")
  const [isLoading, setIsLoading] = React.useState(false)
  const [localError, setLocalError] = React.useState<string | null>(null)
  const passwordInputRef = React.useRef<HTMLInputElement>(null)

  React.useEffect(() => {
    if (open) {
      // Focus password input when dialog opens
      setTimeout(() => passwordInputRef.current?.focus(), 100)
    } else {
      // Reset form when dialog closes
      setPassword("")
      setConfirmPassword("")
      setLocalError(null)
    }
  }, [open])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLocalError(null)

    // Validation
    if (!password) {
      setLocalError("Password is required")
      return
    }

    if (isNewWallet) {
      if (password.length < 8) {
        setLocalError("Password must be at least 8 characters")
        return
      }
      if (password !== confirmPassword) {
        setLocalError("Passwords do not match")
        return
      }
    }

    setIsLoading(true)
    try {
      await onConfirm(password)
      setPassword("")
      setConfirmPassword("")
    } catch (err: any) {
      setLocalError(err.message || "Failed to process password")
    } finally {
      setIsLoading(false)
    }
  }

  const displayError = error || localError

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Lock className="w-5 h-5" />
              {title}
            </DialogTitle>
            <DialogDescription>{description}</DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <label htmlFor="password" className="text-sm font-medium">
                Password
              </label>
              <Input
                id="password"
                ref={passwordInputRef}
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter your password"
                disabled={isLoading}
                className="min-h-[44px]"
                autoComplete={isNewWallet ? "new-password" : "current-password"}
              />
            </div>

            {isNewWallet && (
              <div className="space-y-2">
                <label htmlFor="confirmPassword" className="text-sm font-medium">
                  Confirm Password
                </label>
                <Input
                  id="confirmPassword"
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="Confirm your password"
                  disabled={isLoading}
                  className="min-h-[44px]"
                  autoComplete="new-password"
                />
              </div>
            )}

            {displayError && (
              <div className="flex items-center gap-2 rounded-md bg-destructive/10 p-3 text-sm text-destructive">
                <AlertCircle className="w-4 h-4 flex-shrink-0" />
                <span>{displayError}</span>
              </div>
            )}

            {isNewWallet && (
              <div className="rounded-md bg-muted p-3 text-xs text-muted-foreground">
                <p className="font-medium mb-1">Security Tips:</p>
                <ul className="list-disc list-inside space-y-1">
                  <li>Use at least 8 characters</li>
                  <li>Choose a strong, unique password</li>
                  <li>This password encrypts your wallet on this device</li>
                  <li>You'll need this password to access your wallet</li>
                </ul>
              </div>
            )}
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={isLoading}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isLoading}>
              {isLoading ? "Processing..." : confirmText}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}




