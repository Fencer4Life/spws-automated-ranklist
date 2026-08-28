// Edit-handle generation.
//
// A successful registration hands the browser a short-lived handle over its own
// row, which authorises fn_update_registration to correct the declared name or
// birth year — the two fields the create path cannot change, because they are
// its dedupe arbiter for an unmatched entrant.
//
// The handle is held in component state and nothing else. An earlier design
// persisted it in localStorage so a correction would survive days; that was
// dropped because localStorage is per-origin and per-device — register.html on
// GitHub Pages and the CMS-embedded element cannot see each other's storage, and
// a fencer who registered on a phone could not correct from a laptop. A
// returning fencer instead re-enters the tuple they declared, which upserts onto
// their row and mints a fresh handle. The declared tuple is the credential,
// which it already was everywhere else in this subsystem.

// RFC 4122 v4. The uuid column will reject anything else, so the fallbacks below
// set the version and variant bits explicitly rather than emitting raw hex.
function uuidFromBytes(bytes: Uint8Array): string {
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
}

export function newEditToken(): string {
  try {
    if (typeof crypto?.randomUUID === 'function') return crypto.randomUUID()
  } catch {
    // fall through
  }
  const bytes = new Uint8Array(16)
  try {
    // Older Safari and non-secure contexts have no randomUUID but do have this.
    crypto.getRandomValues(bytes)
  } catch {
    // Last resort only, where neither exists. Weak randomness costs the holder
    // nothing here: the handle authorises one row, and the declared tuple —
    // which anyone can submit anyway — already grants the same access.
    for (let i = 0; i < bytes.length; i++) bytes[i] = Math.floor(Math.random() * 256)
  }
  return uuidFromBytes(bytes)
}
