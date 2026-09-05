/**
 * Where the static image assets live.
 *
 * The four organizer marks and the header mark are referenced by bare file name
 * ('SPWS-logo.png'). That resolves on GitHub Pages, where the app is served
 * from the origin root, but not when the same bundle is embedded in a
 * WordPress page at /znajdz-zawody/ — the browser resolves the bare name
 * against that path and gets a 404.
 *
 * This is a module-level singleton rather than a prop for the same reason
 * `initClient` is: the value arrives once as a static custom-element attribute
 * and is read deep in the tree (EventCard sits below CalendarView and
 * CalendarBarrel). Drilling a prop through three layers to carry a constant
 * would be a larger change than the problem warrants.
 *
 * PROD deployment step 1 — see doc/plans/prod-deployment-wordpress-2026-09-05.html.
 */

let base = ''

/** Set once at element creation. Empty (the default) leaves paths untouched. */
export function setAssetBase(next: string): void {
  base = (next ?? '').trim()
}

/** Current base, mainly for assertions. */
export function getAssetBase(): string {
  return base
}

/**
 * Resolve a bare asset name against the configured base.
 *
 * With no base set this is the identity function, so the GitHub Pages build
 * emits exactly the markup it emits today.
 */
export function assetUrl(name: string): string {
  if (!base) return name
  // Already resolvable on its own: absolute URL, protocol-relative, or rooted.
  if (/^([a-z][a-z0-9+.-]*:|\/\/|\/)/i.test(name)) return name
  return `${base.replace(/\/+$/, '')}/${name.replace(/^\/+/, '')}`
}
