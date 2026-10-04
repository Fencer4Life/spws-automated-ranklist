/**
 * Leave the page for another address, in the same tab.
 *
 * One function, so the one place that navigates on a framed document's request
 * (<spws-document>, WP.DOC.04) can be observed in tests: jsdom does not
 * navigate, and its `location` cannot be spied on.
 */
export function goTo(url: string): void {
  window.location.assign(url)
}
