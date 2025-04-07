/**
 * Direct Web3 Client for Payment Distributor Smart Contract
 * 
 * This module provides functions to interact with the Payment Distributor
 * smart contract without using Anchor.
 */

import { 
  PublicKey, 
  TransactionInstruction,
  SystemProgram,
  LAMPORTS_PER_SOL
} from '@solana/web3.js';

/**
 * Parameters for creating a payment distribution instruction
 */
export interface PaymentDistributionParams {
  /** The program ID of the payment distributor contract */
  programId: string;
  /** The wallet address of the payer */
  payer: string;
  /** The amount to pay in SOL */
  amount: number;
  /** The treasury wallet address */
  treasuryWallet: string;
  /** The team wallet address */
  teamWallet: string;
  /** The first referrer wallet address (optional) */
  firstReferrer?: string | null;
  /** The second referrer wallet address (optional) */
  secondReferrer?: string | null;
}

/**
 * Parameters for creating payment distribution instructions
 */
export interface CreateInstructionsParams {
  /** The amount to pay in SOL */
  amount: number;
  /** The referral code (optional) */
  referralCode?: string;
  /** The wallet address of the payer */
  payer: string;
}

/**
 * Create a payment distribution instruction
 * @param params Parameters for the payment distribution
 * @returns The transaction instruction
 */
export function createPaymentDistributionInstruction({
  programId,
  payer,
  amount,
  treasuryWallet,
  teamWallet,
  firstReferrer = null,
  secondReferrer = null
}: PaymentDistributionParams): TransactionInstruction {
  // Convert amount to lamports (1 SOL = 1,000,000,000 lamports)
  const lamports = Math.floor(amount * LAMPORTS_PER_SOL);
  
  // Create instruction data buffer
  // Format: [amount (8 bytes), hasFirstReferrer (1 byte), hasSecondReferrer (1 byte)]
  const data = Buffer.alloc(10);
  
  // Write amount as little-endian u64 (8 bytes)
  data.writeBigUInt64LE(BigInt(lamports), 0);
  
  // Write referrer flags
  data.writeUInt8(firstReferrer ? 1 : 0, 8);
  data.writeUInt8(secondReferrer ? 1 : 0, 9);
  
  // Create account keys array
  const keys = [
    // Payer account (signer)
    { pubkey: new PublicKey(payer), isSigner: true, isWritable: true },
    
    // Treasury wallet (writable)
    { pubkey: new PublicKey(treasuryWallet), isSigner: false, isWritable: true },
    
    // Team wallet (writable)
    { pubkey: new PublicKey(teamWallet), isSigner: false, isWritable: true },
    
    // First referrer wallet (writable if present)
    {
      pubkey: new PublicKey(firstReferrer || payer), // Use payer as dummy if no referrer
      isSigner: false,
      isWritable: true  // Always writable to match contract expectations
    },
    
    // Second referrer wallet (writable if present)
    {
      pubkey: new PublicKey(secondReferrer || payer), // Use payer as dummy if no referrer
      isSigner: false,
      isWritable: true  // Always writable to match contract expectations
    },
    
    // System program
    { pubkey: SystemProgram.programId, isSigner: false, isWritable: false }
  ];
  
  // Create and return the instruction
  return new TransactionInstruction({
    keys,
    programId: new PublicKey(programId),
    data
  });
}

/**
 * Response from the referrer API
 */
interface ReferrerResponse {
  success: boolean;
  referrerWallet?: string;
  message?: string;
}

/**
 * Create payment distribution instructions for use in a transaction
 * This function is designed to be a drop-in replacement for the missing
 * createPaymentDistributionInstructions function in SignupPage.tsx
 * 
 * @param params Parameters for the payment distribution
 * @returns Array of transaction instructions
 */
export async function createPaymentDistributionInstructions({ 
  amount, 
  referralCode, 
  payer 
}: CreateInstructionsParams): Promise<TransactionInstruction[]> {
  // Import configuration
  const { SolanaConfig } = await import('../config/solana.config.js');
  
  // Resolve referral code to get referrer wallet addresses
  let firstReferrer: string | null = null;
  let secondReferrer: string | null = null;
  
  if (referralCode) {
    try {
      // Fetch the first referrer wallet address from your backend
      const response = await fetch(`/api/whitelist/get-referrer/${referralCode}`);
      const data = await response.json() as ReferrerResponse;
      
      if (data.success && data.referrerWallet) {
        firstReferrer = data.referrerWallet;
        
        // Optionally fetch the second-tier referrer
        try {
          const secondTierResponse = await fetch(`/api/whitelist/get-referrer-of-referrer/${referralCode}`);
          const secondTierData = await secondTierResponse.json() as ReferrerResponse;
          
          if (secondTierData.success && secondTierData.referrerWallet) {
            secondReferrer = secondTierData.referrerWallet;
          }
        } catch (err) {
          console.warn('Error fetching second-tier referrer:', err);
          // Continue without second-tier referrer
        }
      }
    } catch (err) {
      console.warn('Error fetching referrer:', err);
      // Continue without referrers
    }
  }
  
  // Create the instruction
  const instruction = createPaymentDistributionInstruction({
    programId: SolanaConfig.PAYMENT_DISTRIBUTOR_PROGRAM_ID,
    payer,
    amount,
    treasuryWallet: SolanaConfig.TREASURY_WALLET,
    teamWallet: SolanaConfig.TEAM_WALLET,
    firstReferrer,
    secondReferrer
  });
  
  // Return as an array to match the expected interface
  return [instruction];
}