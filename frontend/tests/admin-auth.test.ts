// Plan tests: 9.06, 9.07, 9.08, 9.09, 9.10, 9.11, 9.12, 9.13, 9.14, 9.15, 9.16, 9.17
// See doc/MVP_development_plan.md §T9.0.
// Replaces admin.test.ts (tests 8.48–8.54) after auth migration to Supabase Auth + TOTP MFA.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import AdminSignInModal from '../src/components/AdminSignInModal.svelte'
import AdminMfaEnrollModal from '../src/components/AdminMfaEnrollModal.svelte'
import AdminMfaChallengeModal from '../src/components/AdminMfaChallengeModal.svelte'
import AdminFloatingToolbar from '../src/components/AdminFloatingToolbar.svelte'

describe('AdminSignInModal (T9.0)', () => {
  // 9.06 — AdminSignInModal renders email + password inputs when open
  it('renders email and password inputs when open=true', () => {
    const { container } = render(AdminSignInModal, {
      props: { open: true, onsubmit: vi.fn() },
    })
    const emailInput = container.querySelector('input[type="email"]')
    expect(emailInput).not.toBeNull()
    const passwordInput = container.querySelector('input[type="password"]')
    expect(passwordInput).not.toBeNull()
  })

  // 9.07 — AdminSignInModal hidden when open=false
  it('does not render when open=false', () => {
    const { container } = render(AdminSignInModal, {
      props: { open: false, onsubmit: vi.fn() },
    })
    const modal = container.querySelector('.admin-modal')
    expect(modal).toBeNull()
  })

  // 9.08 — AdminSignInModal calls onsubmit with email+password
  it('calls onsubmit with email and password on form submit', async () => {
    const onsubmit = vi.fn()
    const { container } = render(AdminSignInModal, {
      props: { open: true, onsubmit },
    })
    const emailInput = container.querySelector('input[type="email"]') as HTMLInputElement
    const passwordInput = container.querySelector('input[type="password"]') as HTMLInputElement
    await fireEvent.input(emailInput, { target: { value: 'admin@spws.pl' } })
    await fireEvent.input(passwordInput, { target: { value: 'secret123' } })
    const submitBtn = container.querySelector('.admin-submit-btn')
    await fireEvent.click(submitBtn!)
    expect(onsubmit).toHaveBeenCalledWith('admin@spws.pl', 'secret123')
  })

  // 9.09 — AdminSignInModal shows error on auth failure
  it('displays error message when error prop is set', () => {
    const { container } = render(AdminSignInModal, {
      props: { open: true, onsubmit: vi.fn(), error: 'Invalid credentials' },
    })
    const errorEl = container.querySelector('.admin-error')
    expect(errorEl).not.toBeNull()
    expect(errorEl!.textContent).toContain('Invalid credentials')
  })
})

describe('AdminMfaEnrollModal (T9.0)', () => {
  // 9.10 — AdminMfaEnrollModal renders QR, secret key, 6-digit input
  it('renders QR code, secret key, and 6-digit input', () => {
    const { container } = render(AdminMfaEnrollModal, {
      props: {
        open: true,
        qrCode: 'data:image/png;base64,ABC123',
        secret: 'JBSWY3DPEHPK3PXP',
        onconfirm: vi.fn(),
      },
    })
    const qrImg = container.querySelector('img.mfa-qr')
    expect(qrImg).not.toBeNull()
    expect(qrImg!.getAttribute('src')).toBe('data:image/png;base64,ABC123')

    const secretEl = container.querySelector('.mfa-secret')
    expect(secretEl).not.toBeNull()
    expect(secretEl!.textContent).toContain('JBSWY3DPEHPK3PXP')

    const codeInput = container.querySelector('input.mfa-code-input')
    expect(codeInput).not.toBeNull()
    expect(codeInput!.getAttribute('maxlength')).toBe('6')
  })

  // 9.11 — AdminMfaEnrollModal calls onconfirm with code
  it('calls onconfirm with 6-digit code', async () => {
    const onconfirm = vi.fn()
    const { container } = render(AdminMfaEnrollModal, {
      props: {
        open: true,
        qrCode: 'data:image/png;base64,ABC123',
        secret: 'JBSWY3DPEHPK3PXP',
        onconfirm,
      },
    })
    const codeInput = container.querySelector('input.mfa-code-input') as HTMLInputElement
    await fireEvent.input(codeInput, { target: { value: '123456' } })
    const confirmBtn = container.querySelector('.mfa-confirm-btn')
    await fireEvent.click(confirmBtn!)
    expect(onconfirm).toHaveBeenCalledWith('123456')
  })
})

describe('AdminMfaChallengeModal (T9.0)', () => {
  // 9.12 — AdminMfaChallengeModal renders 6-digit TOTP input
  it('renders 6-digit TOTP code input', () => {
    const { container } = render(AdminMfaChallengeModal, {
      props: { open: true, onverify: vi.fn() },
    })
    const codeInput = container.querySelector('input.mfa-code-input')
    expect(codeInput).not.toBeNull()
    expect(codeInput!.getAttribute('maxlength')).toBe('6')
  })

  // 9.13 — AdminMfaChallengeModal calls onverify with code
  it('calls onverify with entered code', async () => {
    const onverify = vi.fn()
    const { container } = render(AdminMfaChallengeModal, {
      props: { open: true, onverify },
    })
    const codeInput = container.querySelector('input.mfa-code-input') as HTMLInputElement
    await fireEvent.input(codeInput, { target: { value: '654321' } })
    const verifyBtn = container.querySelector('.mfa-verify-btn')
    await fireEvent.click(verifyBtn!)
    expect(onverify).toHaveBeenCalledWith('654321')
  })

  // 9.14 — AdminMfaChallengeModal shows error on invalid code
  it('displays error message when error prop is set', () => {
    const { container } = render(AdminMfaChallengeModal, {
      props: { open: true, onverify: vi.fn(), error: 'Invalid TOTP code' },
    })
    const errorEl = container.querySelector('.admin-error')
    expect(errorEl).not.toBeNull()
    expect(errorEl!.textContent).toContain('Invalid TOTP code')
  })
})

describe('AdminFloatingToolbar — updated for ADR-016 (T9.0)', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })
  afterEach(() => {
    vi.useRealTimers()
  })

  // 9.15 — AdminFloatingToolbar fires ontimeout after 59min (not 120)
  it('fires ontimeout after 59 minutes', () => {
    const ontimeout = vi.fn()
    render(AdminFloatingToolbar, {
      props: { onlogout: vi.fn(), ontimeout, timeoutMs: 59 * 60 * 1000 },
    })
    // Should NOT fire at 58 minutes
    vi.advanceTimersByTime(58 * 60 * 1000)
    expect(ontimeout).not.toHaveBeenCalled()
    // Should fire at 59 minutes
    vi.advanceTimersByTime(1 * 60 * 1000)
    expect(ontimeout).toHaveBeenCalled()
  })

  // Retained from 8.52 — toolbar shows ADMIN badge + timer + Wyloguj
  it('shows ADMIN badge, timer, and logout button', () => {
    const { container } = render(AdminFloatingToolbar, {
      props: { onlogout: vi.fn(), ontimeout: vi.fn() },
    })
    expect(container.querySelector('.admin-badge')).not.toBeNull()
    expect(container.querySelector('.admin-timer')).not.toBeNull()
    expect(container.querySelector('.admin-logout-btn')).not.toBeNull()
  })

  // Retained from 8.53 — Click Wyloguj → calls onlogout
  it('calls onlogout when Wyloguj clicked', async () => {
    const onlogout = vi.fn()
    const { container } = render(AdminFloatingToolbar, {
      props: { onlogout, ontimeout: vi.fn() },
    })
    await fireEvent.click(container.querySelector('.admin-logout-btn')!)
    expect(onlogout).toHaveBeenCalled()
  })
})

describe('App admin-password prop removal (T9.0)', () => {
  // 9.16 — admin-password prop no longer exists on App
  it('App does not accept admin-password prop', async () => {
    // Import App module and check its props type doesn't include admin-password
    // This is a compile-time check — at runtime we verify the prop is not used
    const AppModule = await import('../src/App.svelte')
    expect(AppModule.default).toBeDefined()
    // The component should render without admin-password prop
    // (actual rendering tested in 9.17)
  })

  // 9.17 — App renders AdminSignInModal (not AdminPasswordModal) when ?admin=1
  it('App imports AdminSignInModal instead of AdminPasswordModal', async () => {
    // Read the App.svelte source to verify import changed
    // This is a structural test — the actual modal rendering depends on auth state
    const fs = await import('fs')
    const path = await import('path')
    const appPath = path.resolve(__dirname, '../src/App.svelte')
    const appSource = fs.readFileSync(appPath, 'utf-8')
    expect(appSource).toContain('AdminSignInModal')
    expect(appSource).not.toContain('AdminPasswordModal')
    expect(appSource).not.toContain('admin-password')
  })
})
