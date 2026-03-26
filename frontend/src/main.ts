import { mount } from 'svelte'
import App from './App.svelte'

const target = document.getElementById('spws-ranklist')
if (target) {
  mount(App, {
    target,
    props: {
      'supabase-cert-url': target.getAttribute('supabase-cert-url') ?? '',
      'supabase-cert-key': target.getAttribute('supabase-cert-key') ?? '',
      'supabase-prod-url': target.getAttribute('supabase-prod-url') ?? '',
      'supabase-prod-key': target.getAttribute('supabase-prod-key') ?? '',
      'admin-password': target.getAttribute('admin-password') ?? '',
      demo: target.hasAttribute('demo'),
    },
  })
}
