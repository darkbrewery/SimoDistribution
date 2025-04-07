//! Minimal Payment Distributor Smart Contract

use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    program::invoke,
    pubkey::Pubkey,
    system_instruction,
    program_error::ProgramError,
};

// Program ID - new ID from the generated keypair
solana_program::declare_id!("9eTnS2cYd1mxFvtsm76Hd24Rt5KFdnLQn9zJo9b3jxeT");

// Constants as u8 to save space
const TREASURY_PCT: u8 = 50;
const FIRST_REF_PCT: u8 = 20;
const SECOND_REF_PCT: u8 = 5;
const FIRST_REF_MAX: u64 = 200_000_000;
const SECOND_REF_MAX: u64 = 50_000_000;

// Use the entrypoint! macro instead of manual entrypoint
solana_program::entrypoint!(process_instruction);

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
    let first_referrer = if has_first_referrer { Some(next_account_info(iter)?) } else { None };
    let second_referrer = if has_second_referrer { Some(next_account_info(iter)?) } else { None };
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
    
    let second_ref_amount = if has_second_referrer && has_first_referrer {
        (amount * u64::from(SECOND_REF_PCT) / 100).min(SECOND_REF_MAX)
    } else { 0 };
    
    let second_ref_portion = if has_first_referrer && !has_second_referrer {
        (amount * u64::from(SECOND_REF_PCT) / 100).min(SECOND_REF_MAX)
    } else { 0 };
    
    let team_amount = amount - treasury_amount - first_ref_amount - second_ref_amount + second_ref_portion;
    
    // Transfers
    invoke(
        &system_instruction::transfer(payer.key, treasury.key, treasury_amount),
        &[payer.clone(), treasury.clone(), system_program.clone()],
    )?;
    
    invoke(
        &system_instruction::transfer(payer.key, team.key, team_amount),
        &[payer.clone(), team.clone(), system_program.clone()],
    )?;
    
    if let Some(first_ref) = first_referrer {
        if first_ref_amount > 0 {
            invoke(
                &system_instruction::transfer(payer.key, first_ref.key, first_ref_amount),
                &[payer.clone(), first_ref.clone(), system_program.clone()],
            )?;
        }
    }
    
    if let Some(second_ref) = second_referrer {
        if second_ref_amount > 0 {
            invoke(
                &system_instruction::transfer(payer.key, second_ref.key, second_ref_amount),
                &[payer.clone(), second_ref.clone(), system_program.clone()],
            )?;
        }
    }
    
    Ok(())
}


