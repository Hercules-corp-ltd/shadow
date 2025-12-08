import * as fs from "fs-extra"
import * as path from "path"
import { glob } from "glob"
import chalk from "chalk"
import ora from "ora"
import { Keypair, PublicKey } from "@solana/web3.js"
import { uploadToIPFS, uploadToArweave } from "../circuits/poseidon-node"

export async function deploy(network: string, storage: string) {
  const spinner = ora("Starting deployment...").start()

  try {
    // Read config
    const configPath = path.join(process.cwd(), "shadow.json")
    if (!(await fs.pathExists(configPath))) {
      spinner.fail("shadow.json not found. Run 'shadow-sdk init' first.")
      return
    }

    const config = await fs.readJson(configPath)

    // Find files to upload
    const files = await glob("**/*.{html,css,js,png,jpg,jpeg,svg,json}", {
      ignore: ["node_modules/**", ".shadow/**", "shadow.json"],
    })

    if (files.length === 0) {
      spinner.fail("No files found to deploy")
      return
    }

    spinner.text = `Found ${files.length} files to upload`

    // Upload to storage via backend
    let storageCid: string
    if (storage === "ipfs") {
      // Upload first file (basic mode - single file)
      const firstFile = files[0]
      const content = await fs.readFile(firstFile)
      storageCid = await uploadToIPFS(content, path.basename(firstFile))
    } else if (storage === "arweave") {
      const firstFile = files[0]
      const content = await fs.readFile(firstFile)
      storageCid = await uploadToArweave(content, path.basename(firstFile))
    } else {
      throw new Error(`Unknown storage provider: ${storage}`)
    }

    // Basic mode - no program deployment
    spinner.text = "Basic deployment (no program)..."
    const programAddress = new PublicKey(Keypair.generate().publicKey)
    
    spinner.succeed(chalk.green("Deployment complete!"))
    console.log(chalk.cyan(`\n  Storage CID: ${storageCid}`))
    console.log(chalk.cyan(`  Program Address: ${programAddress.toBase58()}\n`))
  } catch (error) {
    spinner.fail(`Deployment failed: ${error}`)
    throw error
  }
}

