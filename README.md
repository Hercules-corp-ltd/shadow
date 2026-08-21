# Shadow

A pseudonymous web platform on Solana. Profiles and sites are identified by wallet and program addresses — no emails, no usernames.

Your Solana wallet is your identity. Sites are addressed by on-chain program IDs and stored on IPFS or Arweave.

## Repository map

| Path | What it is |
|------|------------|
| `backend/` | Rust (Actix-Web) API |
| `frontend/` | Next.js web client |
| `app/` | React + Vite web app |
| `desktop/` | Vue desktop UI |
| `mobile/` | Flutter client |
| `programs/` | Anchor programs (`shadow-registry`, `shadow-profiles`) |
| `sdk/` | Hermes CLI / site conversion tooling |
| `services/mail-worker/` | Cloudflare Worker for inbound mail aliases |
| `docs/` | Architecture notes and local-run instructions |

## Quick start

```bash
git clone https://github.com/Hercules-corp-ltd/shadow.git
cd shadow
cp env.example .env
```

**Backend** (Rust, MongoDB):

```bash
# Start MongoDB (Docker) then:
cd backend
cargo run
```

The API listens on `http://localhost:8080`. Health check: `GET /api/health`.

**Frontend**:

```bash
cd frontend
npm install
npm run dev
```

**Mobile** (practical local target on Windows): see [docs/running-locally.md](docs/running-locally.md).

Docker Compose can bring up MongoDB, the backend, and the frontend together:

```bash
docker compose up --build
```

## Identity and privacy

- No account emails or usernames in the product model
- Authentication is wallet signatures (`X-Shadow-Auth`)
- Optional Tor integration is sketched in the backend; it is not required to run locally

## Documentation

- [Docs index](docs/README.md)
- [Running locally](docs/running-locally.md)
- [Persistence decision](docs/decisions/0001-postgres-on-supabase.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please keep credentials out of git — `env.example` is placeholders only.

## License

MIT. See [LICENSE](LICENSE).
