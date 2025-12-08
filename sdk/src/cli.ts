#!/usr/bin/env node

import { Command } from "commander"
import { init } from "./commands/init"
import { initFull } from "./commands/init-full"
import { deploy } from "./commands/deploy"
import { deployFull } from "./commands/deploy-full"
import { convertSite } from "./commands/convert"
import chalk from "chalk"

const program = new Command()

program
  .name("shadow-sdk")
  .description("Shadow CLI SDK for deploying sites to the decentralized web")
  .version("0.1.0")

program
  .command("init")
  .description("Initialize a new Shadow site (with Anchor program)")
  .argument("[name]", "Name of the site")
  .option("--basic", "Use basic template (no Anchor)", false)
  .action(async (name, options) => {
    try {
      if (options.basic) {
        await init(name || "my-site")
      } else {
        await initFull(name || "my-site")
      }
    } catch (error) {
      console.error(chalk.red("Error:"), error)
      process.exit(1)
    }
  })

program
  .command("deploy")
  .description("Deploy a Shadow site (compiles program, uploads assets, registers domain)")
  .option("-n, --network <network>", "Network to deploy to", "devnet")
  .option("-s, --storage <storage>", "Storage provider (ipfs|arweave)", "ipfs")
  .option("-d, --domain <domain>", "Register .shadow domain (e.g., mysite.shadow)")
  .option("--mint-token", "Mint SPL token/NFT for site ownership", false)
  .option("--basic", "Use basic deployment (no program compilation)", false)
  .action(async (options) => {
    try {
      if (options.basic) {
        await deploy(options.network, options.storage)
      } else {
        await deployFull(
          options.network,
          options.storage,
          options.domain,
          options.mintToken
        )
      }
    } catch (error) {
      console.error(chalk.red("Error:"), error)
      process.exit(1)
    }
  })

program
  .command("convert")
  .description("Convert existing site to Shadow-compatible format (mints token, uploads assets)")
  .argument("[path]", "Path to site directory", ".")
  .option("-n, --network <network>", "Network (devnet|mainnet-beta)", "devnet")
  .option("-s, --storage <storage>", "Storage provider (ipfs|arweave)", "ipfs")
  .option("--no-mint-token", "Skip token minting (not recommended)")
  .action(async (sitePath, options) => {
    try {
      await convertSite(
        sitePath,
        options.network,
        options.storage,
        options.mintToken !== false
      )
    } catch (error) {
      console.error(chalk.red("Error:"), error)
      process.exit(1)
    }
  })

program.parse()

