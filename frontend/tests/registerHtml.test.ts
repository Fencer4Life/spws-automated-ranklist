// register.html chooses the custom element by ?view= (REVFC.30). There was no
// test of this switch before FR-176 (I36): this runs the page's own inline
// script against a stand-in root and reads which element it mounted.
import { describe, it, expect, beforeEach } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const KEY = '11111111-2222-4333-8444-555555555555'
const page = readFileSync(resolve(__dirname, '../register.html'), 'utf8')
const inline = /<script>\s*([\s\S]*?)<\/script>/.exec(page)![1]

function mount(search: string): HTMLElement {
  window.history.replaceState({}, '', `/register.html${search}`)
  document.body.removeAttribute('style')
  document.body.innerHTML =
    '<div id="reg-root" supabase-cert-url="https://cert.test" supabase-cert-key="anon-cert" ' +
    'supabase-prod-url="" supabase-prod-key="" payee="" iban=""></div>'
  new Function(inline)()
  return document.body.firstElementChild as HTMLElement
}

beforeEach(() => {
  document.body.replaceChildren()
})

describe('REVFC.30 — register.html mounts the element the view names', () => {
  it('view=revenue mounts spws-revenue-report with the event, the key and the database', () => {
    const el = mount(`?event=PEW5&view=revenue&k=${KEY}`)
    expect(el.tagName.toLowerCase()).toBe('spws-revenue-report')
    expect(el.getAttribute('event')).toBe('PEW5')
    expect(el.getAttribute('k')).toBe(KEY)
    expect(el.getAttribute('supabase-cert-url')).toBe('https://cert.test')
    expect(el.getAttribute('supabase-cert-key')).toBe('anon-cert')
    expect(el.hasAttribute('payee')).toBe(false)
    // the report is a light page (plan Q1 = A): no dark frame around it
    expect(document.body.style.background).toBe('rgb(238, 241, 245)')
  })
  it('the other views mount what they did', () => {
    expect(mount('?event=PEW5&view=list').tagName.toLowerCase()).toBe('spws-entry-list')
    const exp = mount(`?event=PEW5&view=export&k=${KEY}`)
    expect(exp.tagName.toLowerCase()).toBe('spws-ftl-export')
    expect(exp.getAttribute('token')).toBe(KEY)
    expect(exp.hasAttribute('k')).toBe(false)
    const reg = mount('?event=PEW5')
    expect(reg.tagName.toLowerCase()).toBe('spws-registration')
    expect(reg.hasAttribute('payee')).toBe(true)
    expect(reg.hasAttribute('k')).toBe(false)
    // the other views keep the page's own dark background
    expect(document.body.style.background).toBe('')
  })
})
