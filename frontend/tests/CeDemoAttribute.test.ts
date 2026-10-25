// CE.DEMO.01 — a bare `demo` attribute turns demo mode on, on every SPWS element.
// F7 on doc/plans/frontend-toolchain-before-after-2026-10-25.html (F7 A, 25 Oct 2026):
// <spws-ranklist> and <spws-calendar> declare `demo` as a Boolean attribute, so
// `<spws-calendar demo>` reads as on. The registration, entry-list and FTL-export
// elements did not, so the attribute arrived as the empty string and read as off.
//
// The other tests pass `demo` as a component prop, which never goes through the
// attribute; these mount the registered custom elements and set the attribute.

import { describe, it, expect, afterEach } from 'vitest'
import { tick } from 'svelte'
import '../src/ce/RanklistElement.svelte'
import '../src/ce/CalendarElement.svelte'
import '../src/ce/RegistrationElement.svelte'
import '../src/ce/EntryListElement.svelte'
import '../src/ce/FtlExportElement.svelte'

const TAGS = ['spws-ranklist', 'spws-calendar', 'spws-registration', 'spws-entry-list', 'spws-ftl-export']

afterEach(() => {
  document.body.replaceChildren()
})

describe('CE.DEMO.01 — a bare demo attribute reads as on', () => {
  for (const tag of TAGS) {
    it(`<${tag} demo>`, async () => {
      const el = document.createElement(tag)
      el.setAttribute('demo', '')
      document.body.appendChild(el)
      await tick()
      await new Promise((resolve) => setTimeout(resolve, 0))
      expect((el as unknown as { demo: unknown }).demo).toBe(true)
    })
  }
})
