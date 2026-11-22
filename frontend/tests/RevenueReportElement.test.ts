// FR-176 — <spws-revenue-report> takes the event and the key (REVFC.30): the key
// from its `k` attribute, else from ?k= in the address. The key is invented.
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  fetchEventForRegistration: vi.fn(),
  fetchRevenueReport: vi.fn(),
}))
import { fetchEventForRegistration, fetchRevenueReport, initClient } from '../src/lib/api'
import RevenueReportElement from '../src/ce/RevenueReportElement.svelte'

const KEY = '11111111-2222-4333-8444-555555555555'

beforeEach(() => {
  vi.clearAllMocks()
  window.history.replaceState({}, '', '/register.html')
  vi.mocked(fetchEventForRegistration).mockResolvedValue({ id_event: 3, txt_code: 'PEW5', txt_name: 'PEW5 Łomianki' } as never)
  vi.mocked(fetchRevenueReport).mockResolvedValue(null)
})

describe('REVFC.30 — the element passes the event and the key on', () => {
  it('from the k attribute', async () => {
    render(RevenueReportElement, { event: 'PEW5', k: KEY, 'supabase-cert-url': 'https://cert.test', 'supabase-cert-key': 'anon' })
    await screen.findByText('Ten link nie jest aktywny. Poproś administratora o nowy.')
    expect(initClient).toHaveBeenCalledWith('https://cert.test', 'anon')
    expect(fetchEventForRegistration).toHaveBeenCalledWith('PEW5')
    expect(fetchRevenueReport).toHaveBeenCalledWith(3, KEY)
  })
  it('from ?k= in the address when there is no attribute', async () => {
    window.history.replaceState({}, '', `/register.html?event=PEW5&view=revenue&k=${KEY}`)
    render(RevenueReportElement, { event: 'PEW5' })
    await screen.findByText('Ten link nie jest aktywny. Poproś administratora o nowy.')
    expect(fetchRevenueReport).toHaveBeenCalledWith(3, KEY)
  })
})
