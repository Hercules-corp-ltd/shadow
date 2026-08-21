use anchor_lang::prelude::*;

declare_id!("8Mc4gjS1y6SZUGQGydtqoHAsjRwCmeux1KjKFYDKqTtu");

#[program]
pub mod shadow_registry {
    use super::*;

    pub fn register_site(
        ctx: Context<RegisterSite>,
        name: String,
        description: String,
        storage_cid: String,
    ) -> Result<()> {
        let site = &mut ctx.accounts.site;
        site.owner = ctx.accounts.owner.key();
        site.program_address = ctx.accounts.program_account.key();
        site.name = name;
        site.description = description;
        site.storage_cid = storage_cid;
        site.created_at = Clock::get()?.unix_timestamp;
        site.updated_at = Clock::get()?.unix_timestamp;

        msg!("Site registered: {}", site.program_address);
        Ok(())
    }

    pub fn update_site(
        ctx: Context<UpdateSite>,
        name: Option<String>,
        description: Option<String>,
        storage_cid: Option<String>,
    ) -> Result<()> {
        let site = &mut ctx.accounts.site;
        
        if let Some(n) = name {
            site.name = n;
        }
        if let Some(d) = description {
            site.description = d;
        }
        if let Some(cid) = storage_cid {
            site.storage_cid = cid;
        }
        
        site.updated_at = Clock::get()?.unix_timestamp;
        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(name: String, description: String, storage_cid: String)]
pub struct RegisterSite<'info> {
    #[account(
        init,
        payer = owner,
        space = 8 + Site::LEN,
        seeds = [b"site", program_account.key().as_ref()],
        bump
    )]
    pub site: Account<'info, Site>,
    
    /// CHECK: The program account being registered
    pub program_account: UncheckedAccount<'info>,
    
    #[account(mut)]
    pub owner: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdateSite<'info> {
    #[account(
        mut,
        seeds = [b"site", site.program_address.as_ref()],
        bump,
        has_one = owner @ ShadowError::Unauthorized
    )]
    pub site: Account<'info, Site>,
    
    pub owner: Signer<'info>,
}

#[account]
pub struct Site {
    pub owner: Pubkey,
    pub program_address: Pubkey,
    pub name: String,
    pub description: String,
    pub storage_cid: String,
    pub created_at: i64,
    pub updated_at: i64,
}

impl Site {
    pub const LEN: usize = 32 + 32 + (4 + 100) + (4 + 500) + (4 + 100) + 8 + 8;
}

#[error_code]
pub enum ShadowError {
    #[msg("Unauthorized")]
    Unauthorized,
}

