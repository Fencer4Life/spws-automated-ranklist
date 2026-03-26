import { getClient } from './api'

export type AuthStep = 'idle' | 'sign_in' | 'mfa_enroll' | 'mfa_challenge' | 'authenticated'

let step = $state<AuthStep>('idle')
let error = $state('')
let qrCode = $state('')
let secret = $state('')
let enrollFactorId = $state('')
let challengeFactorId = $state('')
let challengeId = $state('')

export function getAuthState() {
  return {
    get step() { return step },
    get error() { return error },
    get qrCode() { return qrCode },
    get secret() { return secret },
  }
}

export function startAuth() {
  step = 'sign_in'
  error = ''
}

export function reset() {
  step = 'idle'
  error = ''
  qrCode = ''
  secret = ''
  enrollFactorId = ''
  challengeFactorId = ''
  challengeId = ''
}

export async function signIn(email: string, password: string) {
  error = ''
  try {
    const { data, error: authError } = await getClient().auth.signInWithPassword({ email, password })
    if (authError) {
      error = authError.message
      return
    }
    if (!data.user) {
      error = 'Sign-in failed'
      return
    }

    // Check MFA enrollment
    const { data: factors, error: factorError } = await getClient().auth.mfa.listFactors()
    if (factorError) {
      error = factorError.message
      return
    }

    const totpFactors = factors?.totp ?? []
    if (totpFactors.length === 0) {
      // First time: need to enroll MFA
      const { data: enroll, error: enrollError } = await getClient().auth.mfa.enroll({
        factorType: 'totp',
      })
      if (enrollError) {
        error = enrollError.message
        return
      }
      enrollFactorId = enroll.id
      qrCode = enroll.totp.qr_code
      secret = enroll.totp.secret
      step = 'mfa_enroll'
    } else {
      // Returning user: challenge
      challengeFactorId = totpFactors[0].id
      const { data: challenge, error: challengeError } = await getClient().auth.mfa.challenge({
        factorId: challengeFactorId,
      })
      if (challengeError) {
        error = challengeError.message
        return
      }
      challengeId = challenge.id
      step = 'mfa_challenge'
    }
  } catch (e: unknown) {
    error = e instanceof Error ? e.message : String(e)
  }
}

export async function confirmEnroll(code: string) {
  error = ''
  try {
    const { data: challenge, error: challengeError } = await getClient().auth.mfa.challenge({
      factorId: enrollFactorId,
    })
    if (challengeError) {
      error = challengeError.message
      return
    }
    const { error: verifyError } = await getClient().auth.mfa.verify({
      factorId: enrollFactorId,
      challengeId: challenge.id,
      code,
    })
    if (verifyError) {
      error = verifyError.message
      return
    }
    step = 'authenticated'
  } catch (e: unknown) {
    error = e instanceof Error ? e.message : String(e)
  }
}

export async function verifyChallenge(code: string) {
  error = ''
  try {
    const { error: verifyError } = await getClient().auth.mfa.verify({
      factorId: challengeFactorId,
      challengeId,
      code,
    })
    if (verifyError) {
      error = verifyError.message
      return
    }
    step = 'authenticated'
  } catch (e: unknown) {
    error = e instanceof Error ? e.message : String(e)
  }
}

export async function signOut() {
  await getClient().auth.signOut()
  reset()
}
