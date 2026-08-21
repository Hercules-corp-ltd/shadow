# Security

If you find a vulnerability, please **do not** open a public issue that includes exploit details.

Email **ops@shadow.dev** (or open a private GitHub security advisory on this repository) with:

- a description of the issue
- affected paths or endpoints
- steps to reproduce if you have them

## Secrets

`env.example` must only contain placeholders. A MongoDB Atlas credential was previously committed to this repository; that password lives in git history and should be treated as compromised. Rotate it in Atlas even if the line has been removed.

Do not commit Solana keypairs, `.env` files, or API keys.
