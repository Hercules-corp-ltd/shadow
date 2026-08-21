use anchor_lang::prelude::*;

declare_id!("55VcSJ49rjAqYjxxFKwX9w6tzRUGLgMofGGD9mAGPkff");

#[program]
pub mod shadow_profiles {
    use super::*;

    pub fn create_profile(
        ctx: Context<CreateProfile>,
        profile_cid: String,
        is_public: bool,
    ) -> Result<()> {
        let profile = &mut ctx.accounts.profile;
        profile.wallet = ctx.accounts.wallet.key();
        profile.profile_cid = profile_cid;
        profile.is_public = is_public;
        profile.created_at = Clock::get()?.unix_timestamp;
        profile.updated_at = Clock::get()?.unix_timestamp;

        msg!("Profile created for wallet: {}", profile.wallet);
        Ok(())
    }

    pub fn update_profile(
        ctx: Context<UpdateProfile>,
        profile_cid: Option<String>,
        is_public: Option<bool>,
    ) -> Result<()> {
        let profile = &mut ctx.accounts.profile;
        
        if let Some(cid) = profile_cid {
            profile.profile_cid = cid;
        }
        if let Some(public) = is_public {
            profile.is_public = public;
        }
        
        profile.updated_at = Clock::get()?.unix_timestamp;
        Ok(())
    }
}

#[derive(Accounts)]
pub struct CreateProfile<'info> {
    #[account(
        init,
        payer = wallet,
        space = 8 + Profile::LEN,
        seeds = [b"profile", wallet.key().as_ref()],
        bump
    )]
    pub profile: Account<'info, Profile>,
    
    #[account(mut)]
    pub wallet: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdateProfile<'info> {
    #[account(
        mut,
        seeds = [b"profile", wallet.key().as_ref()],
        bump,
        has_one = wallet @ ShadowError::Unauthorized
    )]
    pub profile: Account<'info, Profile>,
    
    pub wallet: Signer<'info>,
}

#[account]
pub struct Profile {
    pub wallet: Pubkey,
    pub profile_cid: String,
    pub is_public: bool,
    pub created_at: i64,
    pub updated_at: i64,
}

impl Profile {
    pub const LEN: usize = 32 + (4 + 100) + 1 + 8 + 8;
}

#[error_code]
pub enum ShadowError {
    #[msg("Unauthorized")]
    Unauthorized,
}

