import { useEffect, useState } from "react"
import { useParams, useNavigate } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { ArrowLeft } from "lucide-react"

interface Site {
  program_address: string
  owner_pubkey: string
  storage_cid: string
  name: string | null
  description: string | null
}

export default function SitePage() {
  const params = useParams()
  const navigate = useNavigate()
  const program = params.program as string
  const [site, setSite] = useState<Site | null>(null)
  const [content, setContent] = useState<string>("")
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchSite = async () => {
      try {
        const backendUrl = import.meta.env.VITE_BACKEND_URL || "http://localhost:8080"
        const res = await fetch(`${backendUrl}/api/sites/${program}`)
        if (res.ok) {
          const data = await res.json()
          setSite(data)

          // Fetch content
          const contentRes = await fetch(`${backendUrl}/api/sites/${program}/content`)
          if (contentRes.ok) {
            const html = await contentRes.text()
            setContent(html)
          }
        }
      } catch (error) {
        console.error("Error fetching site:", error)
      } finally {
        setLoading(false)
      }
    }

    if (program) {
      fetchSite()
    }
  }, [program])

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

        <div className="max-w-4xl mx-auto">
          {site && (
            <div className="bg-card border border-border rounded-2xl p-6 sm:p-8 mb-6">
              <h1 className="text-2xl sm:text-3xl font-bold mb-2 break-words">
                {site.name || site.program_address}
              </h1>
              {site.description && (
                <p className="text-muted-foreground mb-4 break-words">{site.description}</p>
              )}
            </div>
          )}

          {content ? (
            <div
              className="bg-card border border-border rounded-2xl p-6 sm:p-8 min-h-[400px] overflow-x-auto"
              dangerouslySetInnerHTML={{ __html: content }}
            />
          ) : (
            <div className="bg-card border border-border rounded-2xl p-8 text-center text-muted-foreground">
              No content available
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
