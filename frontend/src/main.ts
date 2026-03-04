import { mount } from 'svelte'
import App from './App.svelte'

const target = document.getElementById('spws-ranklist')
if (target) {
  mount(App, {
    target,
    props: {
      'supabase-url': target.getAttribute('supabase-url') ?? '',
      'supabase-key': target.getAttribute('supabase-key') ?? '',
      demo: target.hasAttribute('demo'),
    },
  })
}
