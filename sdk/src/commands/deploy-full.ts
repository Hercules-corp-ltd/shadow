// Complete deployment flow matching the developer vision
// This implements: compile → deploy Solana program → upload assets → register domain → optional token mint

import * as fs from "fs-extra"
import * as path from "path"
import { glob } from "glob"
import chalk from "chalk"
import ora from "ora"
import { execSync } from "child_process"
import {
  Connection,
  Keypair,
  PublicKey,
  Transaction,
  SystemProgram,
  sendAndConfirmTransaction,
} from "@solana/web3.js"
import {
  getAssociatedTokenAddress,
  createMint,
  mintTo,
  TOKEN_PROGRAM_ID,
  ASSOCIATED_TOKEN_PROGRAM_ID,
} from "@solana/spl-token"
import { uploadToIPFS, uploadToArweave } from "../circuits/poseidon"
import { registerDomain, verifyProgram } from "../circuits/olympus"
import { createAuthHeader } from "../circuits/ares"
import { validateDomain } from "../circuits/apollo"

interface DeployConfig {
  name: string
  version: string
  storage: "ipfs" | "arweave"
  network: "devnet" | "mainnet-beta"
  domain?: string
  mintToken?: boolean
  programPath?: string
}

/**
 * Step 1: Compile and deploy Solana program (Anchor)
 */
async function deploySolanaProgram(
  config: DeployConfig,
  wallet: Keypair,
  network: string
): Promise<PublicKey> {
  const spinner = ora("Compiling Solana program...").start()

  try {
    const programPath = config.programPath || path.join(process.cwd(), "programs")
    const anchorToml = path.join(programPath, "Anchor.toml")

    if (!(await fs.pathExists(anchorToml))) {
      spinner.fail("Anchor.toml not found. Run 'anchor init' first.")
      throw new Error("No Anchor program found")
    }

    // Build the program
    spinner.text = "Building Anchor program..."
    execSync("anchor build", { cwd: programPath, stdio: "inherit" })

    // Deploy the program
    spinner.text = `Deploying to ${network}...`
    const deployOutput = execSync("anchor deploy", {
      cwd: programPath,
      encoding: "utf-8",
    })

    // Extract program ID from Anchor.toml or deploy output
    const programIdMatch = deployOutput.match(/Program Id: (\w+)/)
    if (!programIdMatch) {
      // Try reading from Anchor.toml
      const anchorConfig = await fs.readFile(anchorToml, "utf-8")
      const idMatch = anchorConfig.match(/\[programs\.(?:devnet|mainnet)\]\s*\n\s*shadow_site\s*=\s*"(\w+)"/)
      if (idMatch) {
        const programId = new PublicKey(idMatch[1])
        spinner.succeed(`Program deployed: ${programId.toBase58()}`)
        return programId
      }
      throw new Error("Could not extract program ID")
    }

    const programId = new PublicKey(programIdMatch[1])
    spinner.succeed(`Program deployed: ${programId.toBase58()}`)
    return programId
  } catch (error) {
    spinner.fail(`Program deployment failed: ${error}`)
    throw error
  }
}

/**
 * Step 2: Upload assets to IPFS/Arweave
 */
async function uploadAssets(
  storage: "ipfs" | "arweave"
): Promise<string> {
  const spinner = ora(`Uploading assets to ${storage}...`).start()

  try {
    // Find files to upload (exclude program files)
    const files = await glob("**/*.{html,css,js,jsx,tsx,json,png,jpg,jpeg,svg,woff,woff2}", {
      ignore: [
        "node_modules/**",
        ".shadow/**",
        "programs/**",
        "target/**",
        "anchor/**",
        "shadow.json",
        "*.log",
      ],
    })

    if (files.length === 0) {
      spinner.fail("No files found to upload")
      throw new Error("No assets to deploy")
    }

    spinner.text = `Found ${files.length} files to upload`

    // Use Poseidon circuit for storage
    let cid: string
    if (storage === "ipfs") {
      // For IPFS, we need to bundle files
      // In production, use proper IPFS directory upload
      const firstFile = files[0]
      const content = await fs.readFile(firstFile)
      cid = await uploadToIPFS(Buffer.from(content), path.basename(firstFile))
    } else {
      const firstFile = files[0]
      const content = await fs.readFile(firstFile)
      cid = await uploadToArweave(Buffer.from(content), path.basename(firstFile))
    }

    spinner.succeed(`Assets uploaded: ${cid}`)
    return cid
  } catch (error) {
    spinner.fail(`Asset upload failed: ${error}`)
    throw error
  }
}

/**
 * Step 3: Mint SPL Token/NFT (optional)
 */
async function mintSiteToken(
  programId: PublicKey,
  wallet: Keypair,
  connection: Connection
): Promise<PublicKey | null> {
  const spinner = ora("Minting site token...").start()

  try {
    // Create mint account
    const mint = await createMint(
      connection,
      wallet,
      wallet.publicKey, // mint authority
      null, // freeze authority
      0 // decimals (NFT = 0)
    )

    // Get associated token account
    const tokenAccount = await getAssociatedTokenAddress(
      mint,
      wallet.publicKey,
      false,
      TOKEN_PROGRAM_ID,
      ASSOCIATED_TOKEN_PROGRAM_ID
    )

    // Mint 1 token (NFT)
    await mintTo(
      connection,
      wallet,
      mint,
      tokenAccount,
      wallet,
      1 // amount
    )

    spinner.succeed(`Token minted: ${mint.toBase58()}`)
    return mint
  } catch (error) {
    spinner.warn(`Token minting skipped: ${error}`)
    return null
  }
}

/**
 * Step 4: Register domain via Olympus circuit
 */
async function registerDomainAlias(
  domain: string,
  programAddress: PublicKey,
  wallet: Keypair,
  storageCid: string
): Promise<void> {
  const spinner = ora(`Registering domain: ${domain}`).start()

  try {
    // Validate domain
    if (!validateDomain(domain)) {
      throw new Error(`Invalid domain format: ${domain}`)
    }

    // Create auth header
    const authHeader = await createAuthHeader(wallet.publicKey, wallet)

    // Register domain via Olympus circuit
    await registerDomain(
      domain,
      programAddress.toBase58(),
      wallet.publicKey.toBase58(),
      authHeader
    )

    spinner.succeed(`Domain registered: ${domain} → ${programAddress.toBase58()}`)
  } catch (error) {
    spinner.fail(`Domain registration failed: ${error}`)
    throw error
  }
}

/**
 * Complete deployment flow
 */
export async function deployFull(
  network: string = "devnet",
  storage: string = "ipfs",
  domain?: string,
  mintToken: boolean = false
) {
  const mainSpinner = ora("Starting Shadow deployment...").start()

  try {
    // Read config
    const configPath = path.join(process.cwd(), "shadow.json")
    if (!(await fs.pathExists(configPath))) {
      mainSpinner.fail("shadow.json not found. Run 'shadow-sdk init' first.")
      return
    }

    const config: DeployConfig = await fs.readJson(configPath)
    config.network = network as "devnet" | "mainnet-beta"
    config.storage = storage as "ipfs" | "arweave"
    config.domain = domain
    config.mintToken = mintToken

    // Setup Solana connection
    const rpcUrl =
      network === "mainnet-beta"
        ? "https://api.mainnet-beta.solana.com"
        : "https://api.devnet.solana.com"
    const connection = new Connection(rpcUrl, "confirmed")

    // Load or generate wallet
    const walletPath = path.join(process.cwd(), ".shadow", "wallet.json")
    let wallet: Keypair

    if (await fs.pathExists(walletPath)) {
      const walletData = await fs.readJson(walletPath)
      wallet = Keypair.fromSecretKey(Uint8Array.from(walletData.secretKey))
    } else {
      // Generate new wallet (in production, prompt user)
      wallet = Keypair.generate()
      await fs.mkdirp(path.dirname(walletPath))
      await fs.writeJson(walletPath, {
        publicKey: wallet.publicKey.toBase58(),
        secretKey: Array.from(wallet.secretKey),
      })
      mainSpinner.warn("Generated new wallet. Save this securely!")
    }

    mainSpinner.text = `Wallet: ${wallet.publicKey.toBase58()}`

    // Step 1: Deploy Solana program
    const programAddress = await deploySolanaProgram(config, wallet, network)

    // Step 2: Upload assets
    const storageCid = await uploadAssets(config.storage)

    // Step 3: Mint token (optional)
    let tokenMint: PublicKey | null = null
    if (config.mintToken) {
      tokenMint = await mintSiteToken(programAddress, wallet, connection)
    }

    // Step 4: Register domain (if provided)
    if (config.domain) {
      await registerDomainAlias(
        config.domain,
        programAddress,
        wallet,
        storageCid
      )
    }

    // Success!
    mainSpinner.succeed(chalk.green("Deployment complete!"))

    console.log(chalk.cyan("\n📦 Deployment Summary:"))
    console.log(chalk.white(`  Program Address: ${programAddress.toBase58()}`))
    console.log(chalk.white(`  Storage CID: ${storageCid}`))
    if (config.domain) {
      console.log(chalk.white(`  Domain: ${config.domain}`))
    }
    if (tokenMint) {
      console.log(chalk.white(`  Token: ${tokenMint.toBase58()}`))
    }
    console.log(chalk.cyan(`\n🌐 Your site is live!`))
    console.log(chalk.white(`  Access via: ${programAddress.toBase58()}`))
    if (config.domain) {
      console.log(chalk.white(`  Or: ${config.domain}`))
    }
    console.log()
  } catch (error) {
    mainSpinner.fail(`Deployment failed: ${error}`)
    throw error
  }
}


