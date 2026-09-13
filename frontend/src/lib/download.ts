// Browser-side file delivery for generated content.
//
// The FTL export page is static-hosted, so a "download" is a Blob, an object
// URL and a synthetic click. Kept in one place because the revoke is the part
// that gets forgotten: without it every download leaks its blob for the life of
// the page, and the organizer may generate the whole bundle several times while
// entries trickle in on the morning of the event.

export function downloadBytes(filename: string, data: BlobPart, mime: string): void {
  const url = URL.createObjectURL(new Blob([data], { type: mime }))
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.rel = 'noopener'
  a.click()
  URL.revokeObjectURL(url)
}

export function downloadText(filename: string, text: string, mime = 'application/xml'): void {
  // The BOM-less UTF-8 the FIE files declare in their own XML declaration.
  downloadBytes(filename, text, `${mime};charset=utf-8`)
}
