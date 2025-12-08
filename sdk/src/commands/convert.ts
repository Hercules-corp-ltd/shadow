// Convert existing site to Shadow-compatible site
// This enables developers to convert their existing projects to work with Shadow browser

import * as fs from "fs-extra"
import * as path from "path"
import chalk from "chalk"
import ora from "ora"
import { glob } from "glob"
import { Keypair, PublicKey } from "@solana/web3.js"
import { createMint, getAssociatedTokenAddress, mintTo, TOKEN_PROGRAM_ID, ASSOCIATED_TOKEN_PROGRAM_ID } from "@solana/spl-token"
import { Connection } from "@solana/web3.js"
import { uploadToIPFS, uploadToArweave, uploadDirectoryToIPFS } from "../circuits/poseidon-node"
import { registerDomain } from "../circuits/olympus"
import { createAuthHeader } from "../circuits/ares"
import { validateDomain } from "../circuits/apollo"

/**
 * Convert an existing site to Shadow-compatible format
 * - Creates Solana program (or uses existing)
 * - Mints site token (used as domain)
 * - Uploads assets to IPFS/Arweave
 * - Registers token address as domain
 */
export async function convertSite(
  sitePath: string = ".",
  network: string = "devnet",
  storage: string = "ipfs",
  mintToken: boolean = true
) {
  const spinner = ora("Converting site to Shadow format...").start()

  try {
    const projectDir = path.resolve(process.cwd(), sitePath)
    
    if (!(await fs.pathExists(projectDir))) {
      spinner.fail(`Directory not found: ${projectDir}`)
      return
    }

    spinner.text = "Analyzing existing site..."

    // Check if already a Shadow site
    const shadowJson = path.join(projectDir, "shadow.json")
    if (await fs.pathExists(shadowJson)) {
      spinner.warn("Site already appears to be a Shadow site")
      const config = await fs.readJson(shadowJson)
      console.log(chalk.cyan(`\n  Program Address: ${config.programAddress || "Not set"}`))
      console.log(chalk.cyan(`  Token: ${config.tokenMint || "Not set"}\n`))
      return
    }

    // Find site files
    const siteFiles = await glob("**/*.{html,css,js,jsx,tsx,json,png,jpg,jpeg,svg,woff,woff2}", {
      cwd: projectDir,
      ignore: [
        "node_modules/**",
        ".git/**",
        "dist/**",
        "build/**",
        ".next/**",
        ".shadow/**",
        "package-lock.json",
        "yarn.lock",
      ],
    })

    if (siteFiles.length === 0) {
      spinner.fail("No site files found")
      return
    }

    spinner.text = `Found ${siteFiles.length} files to process`

    // Setup Solana connection
    const rpcUrl =
      network === "mainnet-beta"
        ? "https://api.mainnet-beta.solana.com"
        : "https://api.devnet.solana.com"
    const connection = new Connection(rpcUrl, "confirmed")

    // Load or create wallet
    const walletPath = path.join(projectDir, ".shadow", "wallet.json")
    let wallet: Keypair

    if (await fs.pathExists(walletPath)) {
      const walletData = await fs.readJson(walletPath)
      wallet = Keypair.fromSecretKey(Uint8Array.from(walletData.secretKey))
    } else {
      wallet = Keypair.generate()
      await fs.mkdirp(path.dirname(walletPath))
      await fs.writeJson(walletPath, {
        publicKey: wallet.publicKey.toBase58(),
        secretKey: Array.from(wallet.secretKey),
      })
      spinner.warn("Generated new wallet. Save this securely!")
    }

    spinner.text = `Wallet: ${wallet.publicKey.toBase58()}`

    // Step 1: Upload assets
    spinner.text = `Uploading ${siteFiles.length} files to ${storage}...`
    const fileContents = await Promise.all(
      siteFiles.map(async (file) => ({
        path: file,
        content: await fs.readFile(path.join(projectDir, file)),
      }))
    )

    let storageCid: string
    if (storage === "ipfs") {
      storageCid = await uploadDirectoryToIPFS(fileContents)
    } else {
      // For Arweave, upload first file (or bundle in production)
      storageCid = await uploadToArweave(fileContents[0].content, fileContents[0].path)
    }

    spinner.succeed(`Assets uploaded: ${storageCid}`)

    // Step 2: Mint site token (used as domain/identifier)
    let tokenMint: PublicKey | null = null
    let programAddress: PublicKey

    if (mintToken) {
      spinner.text = "Minting site token..."
      
      // Create token mint (this becomes the site's "domain")
      tokenMint = await createMint(
        connection,
        wallet,
        wallet.publicKey, // mint authority
        null, // freeze authority
        0 // decimals (NFT = 0, represents unique site)
      )

      // Get associated token account
      const tokenAccount = await getAssociatedTokenAddress(
        tokenMint,
        wallet.publicKey,
        false,
        TOKEN_PROGRAM_ID,
        ASSOCIATED_TOKEN_PROGRAM_ID
      )

      // Mint 1 token (site ownership NFT)
      await mintTo(
        connection,
        wallet,
        tokenMint,
        tokenAccount,
        wallet,
        1
      )

      spinner.succeed(`Site token minted: ${tokenMint.toBase58()}`)
      
      // Use token address as program address (for Shadow browser)
      programAddress = tokenMint
    } else {
      // If no token, generate a program address
      programAddress = wallet.publicKey
    }

    // Step 3: Register token address as domain
    spinner.text = "Registering site..."
    const authHeader = await createAuthHeader(wallet.publicKey, wallet)
    
    // Register token address as a .shadow domain
    const tokenDomain = `${tokenMint?.toBase58().slice(0, 8)}.shadow`
    try {
      await registerDomain(
        tokenDomain,
        programAddress.toBase58(),
        wallet.publicKey.toBase58(),
        authHeader
      )
      spinner.succeed(`Domain registered: ${tokenDomain}`)
    } catch (error) {
      spinner.warn(`Domain registration skipped: ${error}`)
    }

    // Step 4: Create shadow.json config
    const config = {
      name: path.basename(projectDir),
      version: "1.0.0",
      storage: storage,
      network: network,
      storageCid: storageCid,
      programAddress: programAddress.toBase58(),
      tokenMint: tokenMint?.toBase58() || null,
      domain: tokenDomain,
      converted: true,
      convertedAt: new Date().toISOString(),
    }

    await fs.writeJson(shadowJson, config, { spaces: 2 })

    // Step 5: Create Shadow integration file
    const shadowIntegration = `// Shadow Browser Integration
// This file enables your site to work with Shadow browser

export const SHADOW_CONFIG = {
  programAddress: "${programAddress.toBase58()}",
  tokenMint: "${tokenMint?.toBase58() || ""}",
  domain: "${tokenDomain}",
  storageCid: "${storageCid}",
  network: "${network}",
}

// Use this in your site to interact with Shadow
export function getShadowAddress(): string {
  return SHADOW_CONFIG.programAddress
}

export function getShadowDomain(): string {
  return SHADOW_CONFIG.domain
}
`

    const integrationPath = path.join(projectDir, "shadow-integration.js")
    await fs.writeFile(integrationPath, shadowIntegration)

    // Success!
    spinner.succeed(chalk.green("Site converted to Shadow format!"))

    console.log(chalk.cyan("\n📦 Conversion Summary:"))
    console.log(chalk.white(`  Program Address: ${programAddress.toBase58()}`))
    if (tokenMint) {
      console.log(chalk.white(`  Site Token: ${tokenMint.toBase58()}`))
      console.log(chalk.white(`  Token Domain: ${tokenDomain}`))
    }
    console.log(chalk.white(`  Storage CID: ${storageCid}`))
    console.log(chalk.cyan(`\n🌐 Your site is now Shadow-compatible!`))
    console.log(chalk.white(`  Access via: ${programAddress.toBase58()}`))
    if (tokenMint) {
      console.log(chalk.white(`  Or via token: ${tokenMint.toBase58()}`))
      console.log(chalk.white(`  Or via domain: ${tokenDomain}`))
    }
    console.log(chalk.cyan(`\n📝 Next steps:`))
    console.log(chalk.white(`  1. Import shadow-integration.js in your site`))
    console.log(chalk.white(`  2. Deploy your site normally`))
    console.log(chalk.white(`  3. Shadow browser will use the contract address`))
    console.log()
  } catch (error) {
    spinner.fail(`Conversion failed: ${error}`)
    throw error
  }
}


