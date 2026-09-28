// A stand-in for src/lib/admin-auth.svelte.ts whose sign-in state a test can
// flip on an already-mounted App. The real module only reaches 'authenticated'
// through Supabase auth calls; this keeps the same reactive getter shape
// (App derives isAdmin from auth.step), so a test observes exactly what App
// does when an admin signs in on the open page.

import type { AuthStep } from '../../src/lib/admin-auth.svelte'

let step: AuthStep = $state('idle')

export function setAuthStep(next: AuthStep): void {
  step = next
}

export function getAuthState() {
  return {
    get step() { return step },
    get error() { return '' },
    get qrCode() { return '' },
    get secret() { return '' },
  }
}

export function startAuth(): void {
  step = 'sign_in'
}

export function reset(): void {
  step = 'idle'
}

export async function signIn(): Promise<void> {}
export async function confirmEnroll(): Promise<void> {}
export async function verifyChallenge(): Promise<void> {}
export async function signOut(): Promise<void> {
  step = 'idle'
}
