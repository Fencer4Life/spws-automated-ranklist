// Smoke test — verifies Vitest is configured and running correctly.
// Infrastructure only; no plan test ID.
import { describe, it, expect } from 'vitest'

describe('vitest', () => {
  it('is working', () => {
    expect(true).toBe(true)
  })
})
