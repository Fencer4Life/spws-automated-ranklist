import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import FilterBar from '../src/components/FilterBar.svelte'

describe('FilterBar', () => {
  it('renders all filter controls', () => {
    const { container } = render(FilterBar)
    const selects = container.querySelectorAll('select')
    expect(selects.length).toBe(3) // weapon, gender, category
    const toggleBtns = container.querySelectorAll('.toggle-btn')
    expect(toggleBtns.length).toBe(2) // PPW, Kadra
  })

  it('PPW is active by default', () => {
    const { container } = render(FilterBar)
    const btns = container.querySelectorAll('.toggle-btn')
    expect(btns[0].classList.contains('active')).toBe(true)
    expect(btns[1].classList.contains('active')).toBe(false)
  })

  it('disables Kadra button when category is V0', () => {
    const { container } = render(FilterBar, { props: { category: 'V0' } })
    const kadraBtn = container.querySelectorAll('.toggle-btn')[1] as HTMLButtonElement
    expect(kadraBtn.disabled).toBe(true)
  })

  it('emits filter change on weapon select', async () => {
    const handler = vi.fn()
    const { container } = render(FilterBar, { props: { onfilterchange: handler } })
    const weaponSelect = container.querySelectorAll('select')[0]
    await fireEvent.change(weaponSelect, { target: { value: 'FOIL' } })
    expect(handler).toHaveBeenCalled()
  })

  it('switches to PPW when V0 selected while in Kadra mode', async () => {
    const handler = vi.fn()
    const { container } = render(FilterBar, {
      props: { mode: 'KADRA', onfilterchange: handler },
    })
    const categorySelect = container.querySelectorAll('select')[2]
    await fireEvent.change(categorySelect, { target: { value: 'V0' } })
    const call = handler.mock.calls[handler.mock.calls.length - 1][0]
    expect(call.mode).toBe('PPW')
  })
})
