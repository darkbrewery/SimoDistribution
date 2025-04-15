//! Minimal Payment Distributor Smart Contract

use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    program::invoke,
    pubkey::Pubkey,
    system_instruction,
    program_error::ProgramError,
};

use solana_security_txt::security_txt;

// Program ID - new ID from the generated keypair
solana_program::declare_id!("6CGfhGv77UGNVXHYAi3hZJDozf2D7c6cagRC45e7WY7z");

// Constants as u8 to save space
const TREASURY_PCT: u8 = 50;
const FIRST_REF_PCT: u8 = 20;
const SECOND_REF_PCT: u8 = 5;
const FIRST_REF_MAX: u64 = 200_000_000;
const SECOND_REF_MAX: u64 = 50_000_000;

// Use the entrypoint! macro instead of manual entrypoint
solana_program::entrypoint!(process_instruction);

security_txt! {
    name: "Project Simo Distribution",
    project_url: "https://projectsimo.io",
    contacts: "discord:https://discord.gg/projectsimo",
    policy: "https://projectsimo.io/security-policy",
    preferred_languages: "en",
    source_code: "https://github.com/darkbrewery/SimoDistribution"
}

// Add inline attribute to encourage compiler to inline this function
#[inline]

fn process_instruction(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    // Parse instruction data
    if instruction_data.len() < 8 {
        return Err(ProgramError::InvalidInstructionData);
    }

    let amount = u64::from_le_bytes(instruction_data[0..8].try_into().unwrap());
    let has_first_referrer = instruction_data.get(8).map_or(false, |&flag| flag != 0);
    let has_second_referrer = instruction_data.get(9).map_or(false, |&flag| flag != 0);

    // Extract accounts
    let iter = &mut accounts.iter();
    let payer = next_account_info(iter)?;
    let treasury = next_account_info(iter)?;
    let team = next_account_info(iter)?;

    // Always extract both referrer accounts, regardless of flags
    let first_referrer = next_account_info(iter)?;
    let second_referrer = next_account_info(iter)?;
    let system_program = next_account_info(iter)?;

    // Verify system program ID
    if *system_program.key != solana_program::system_program::ID {
        return Err(ProgramError::IncorrectProgramId);
    }

    // Calculate amounts
    let treasury_amount = amount * u64::from(TREASURY_PCT) / 100;

    let first_ref_amount = if has_first_referrer {
        (amount * u64::from(FIRST_REF_PCT) / 100).min(FIRST_REF_MAX)
    } else { 0 };

    let second_ref_amount = if has_second_referrer {
        (amount * u64::from(SECOND_REF_PCT) / 100).min(SECOND_REF_MAX)
    } else { 0 };

    let team_amount = amount - treasury_amount - first_ref_amount - second_ref_amount;

    // Transfers
    invoke(
        &system_instruction::transfer(payer.key, treasury.key, treasury_amount),
        &[payer.clone(), treasury.clone(), system_program.clone()],
    )?;

    invoke(
        &system_instruction::transfer(payer.key, team.key, team_amount),
        &[payer.clone(), team.clone(), system_program.clone()],
    )?;

    // Only transfer to first referrer if the flag is set and amount is positive
    if has_first_referrer && first_ref_amount > 0 {
        invoke(
            &system_instruction::transfer(payer.key, first_referrer.key, first_ref_amount),
            &[payer.clone(), first_referrer.clone(), system_program.clone()],
        )?;
    }

    // Only transfer to second referrer if the flag is set and amount is positive
    if has_second_referrer && second_ref_amount > 0 {
        invoke(
            &system_instruction::transfer(payer.key, second_referrer.key, second_ref_amount),
            &[payer.clone(), second_referrer.clone(), system_program.clone()],
        )?;
    }

    Ok(())
}







