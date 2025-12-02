// Enhanced init command that creates Anchor program template + off-chain assets

import * as fs from "fs-extra"
import * as path from "path"
import chalk from "chalk"
import ora from "ora"
import { execSync } from "child_process"

export async function initFull(name: string) {
  const spinner = ora(`Initializing Shadow site: ${name}`).start()

  try {
    const dir = path.resolve(process.cwd(), name)

    if (await fs.pathExists(dir)) {
      spinner.fail(`Directory ${name} already exists`)
      return
    }

    await fs.mkdirp(dir)

    // Step 1: Initialize Anchor program
    spinner.text = "Initializing Anchor program..."
    try {
      execSync(`anchor init ${name} --no-git`, {
        cwd: process.cwd(),
        stdio: "pipe",
      })
    } catch (error) {
      // If anchor init fails, create basic structure
      spinner.warn("Anchor CLI not found, creating basic structure...")
      await createBasicAnchorStructure(dir, name)
    }

    // Step 2: Create off-chain assets directory
    const assetsDir = path.join(dir, "assets")
    await fs.mkdirp(assetsDir)

    // Step 3: Create React/HTML template
    const indexHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${name}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: system-ui, -apple-system, sans-serif;
            background: #0a0a0a;
            color: #fff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            max-width: 800px;
            padding: 2rem;
            text-align: center;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        p {
            color: #888;
            font-size: 1.2rem;
        }
        .shadow-badge {
            display: inline-block;
            margin-top: 2rem;
            padding: 0.5rem 1rem;
            background: rgba(102, 126, 234, 0.1);
            border: 1px solid rgba(102, 126, 234, 0.3);
            border-radius: 0.5rem;
            color: #667eea;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to ${name}</h1>
        <p>This is your Shadow site. Edit this file to customize your content.</p>
        <div class="shadow-badge">Built on Shadow</div>
    </div>
    <script>
        // Connect to Solana program
        // Example: const programId = new PublicKey('YOUR_PROGRAM_ID');
        console.log('Shadow site loaded');
    </script>
</body>
</html>`

    await fs.writeFile(path.join(assetsDir, "index.html"), indexHtml)

    // Step 4: Create shadow.json config
    const config = {
      name: name,
      version: "0.1.0",
      storage: "ipfs",
      network: "devnet",
      programPath: "./programs",
    }

    await fs.writeFile(
      path.join(dir, "shadow.json"),
      JSON.stringify(config, null, 2)
    )

    // Step 5: Create .gitignore
    const gitignore = `node_modules/
.shadow/
target/
*.log
.DS_Store
dist/
build/
`

    await fs.writeFile(path.join(dir, ".gitignore"), gitignore)

    // Step 6: Create README
    const readme = `# ${name}

Shadow site built on Solana.

## Development

\`\`\`bash
# Build the Solana program
anchor build

# Deploy
npx shadow-sdk deploy

# Deploy with domain
npx shadow-sdk deploy --domain ${name}.shadow

# Deploy with token
npx shadow-sdk deploy --mint-token
\`\`\`

## Structure

- \`programs/\` - Solana program (Anchor)
- \`assets/\` - Off-chain content (HTML/JS/CSS)
- \`shadow.json\` - Configuration

## Learn More

Visit [Shadow Docs](https://shadow.xyz/docs) for more information.
`

    await fs.writeFile(path.join(dir, "README.md"), readme)

    spinner.succeed(chalk.green(`Shadow site initialized: ${name}`))
    console.log(chalk.cyan(`\n  cd ${name}`))
    console.log(chalk.cyan(`  anchor build`))
    console.log(chalk.cyan(`  npx shadow-sdk deploy\n`))
  } catch (error) {
    spinner.fail(`Failed to initialize: ${error}`)
    throw error
  }
}

async function createBasicAnchorStructure(dir: string, name: string) {
  const programsDir = path.join(dir, "programs", name)
  await fs.mkdirp(programsDir)

  // Create basic Anchor program
  const libRs = `use anchor_lang::prelude::*;

declare_id!("11111111111111111111111111111111");

#[program]
pub mod ${name.replace(/-/g, "_")} {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Shadow site initialized!");
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
`

  await fs.writeFile(path.join(programsDir, "src", "lib.rs"), libRs)

  // Create Anchor.toml
  const anchorToml = `[features]
resolution = true
skip-lint = false

[programs.devnet]
${name.replace(/-/g, "_")} = "11111111111111111111111111111111"

[registry]
url = "https://api.apr.dev"

[provider]
cluster = "Devnet"
wallet = "~/.config/solana/id.json"

[scripts]
test = "yarn run ts-mocha -p ./tsconfig.json -t 1000000 tests/**/*.ts"
`

  await fs.writeFile(path.join(dir, "Anchor.toml"), anchorToml)
}

