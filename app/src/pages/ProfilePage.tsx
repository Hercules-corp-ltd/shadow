import { useEffect, useState } from "react"
import { useParams, useNavigate } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { shortenAddress } from "@/lib/utils"
import { ArrowLeft, User } from "lucide-react"

interface Profile {
  wallet_pubkey: string
  profile_cid: string | null
  is_public: boolean
  exists: boolean
}

export default function ProfilePage() {
  const params = useParams()
  const navigate = useNavigate()
  const wallet = params.wallet as string
  const [profile, setProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const backendUrl = import.meta.env.VITE_BACKEND_URL || "http://localhost:8080"
        const res = await fetch(`${backendUrl}/api/profiles/${wallet}`)
        if (res.ok) {
          const data = await res.json()
          setProfile(data)
        }
      } catch (error) {
        console.error("Error fetching profile:", error)
      } finally {
        setLoading(false)
      }
    }

    if (wallet) {
      fetchProfile()
    }
  }, [wallet])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-muted-foreground">Loading...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background">
      <div className="container mx-auto px-4 py-8">
        <Button
          variant="ghost"
          onClick={() => navigate(-1)}
          className="mb-6"
        >
          <ArrowLeft className="w-4 h-4 mr-2" />
          Back
        </Button>

        <div className="max-w-2xl mx-auto">
          <div className="bg-card border border-border rounded-2xl p-6 sm:p-8">
            <div className="flex flex-col sm:flex-row items-center sm:items-start gap-4 mb-6">
              <div className="w-20 h-20 rounded-full bg-muted flex items-center justify-center flex-shrink-0">
                <User className="w-10 h-10 text-muted-foreground" />
              </div>
              <div className="text-center sm:text-left">
                <h1 className="text-2xl sm:text-3xl font-bold break-all">
                  {shortenAddress(wallet)}
                </h1>
                {profile?.is_public && (
                  <p className="text-muted-foreground mt-1">Public Profile</p>
                )}
              </div>
            </div>

            {profile?.exists ? (
              <div>
                {profile.is_public ? (
                  <div>
                    {profile.profile_cid && (
                      <p className="text-muted-foreground mb-4 break-all text-sm">
                        Profile CID: {profile.profile_cid}
                      </p>
                    )}
                  </div>
                ) : (
                  <p className="text-muted-foreground">
                    This profile is anonymous.
                  </p>
                )}
              </div>
            ) : (
              <p className="text-muted-foreground">
                Profile does not exist yet.
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
