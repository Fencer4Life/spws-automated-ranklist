// A minimal, dependency-free ZIP writer — the browser twin of
// python/pipeline/ftl_seed_export.py's bundle_seed_zip.
//
// WHY WRITE ONE. PPW1 produces 25 seed files. A browser will not let a page
// start 25 downloads, and handing the organizer 25 separate links to click the
// morning of the event is not a delivery mechanism. The Python exporter already
// bundles them for the e-mail path; the public page needs the same thing, and
// the page is static-hosted so it cannot ask a server to do it.
//
// STORED, NOT DEFLATED. The archive uses compression method 0 (store), which is
// a first-class part of the format that every unzip implementation — including
// Windows Explorer's built-in one, which is what the venue machine will use —
// has supported since the beginning. Deflate would need a compressor; these are
// small XML files and the whole bundle is a few tens of kilobytes either way.
// The cost of "store" is size we do not care about; the benefit is that this
// file is short enough to read and verify in full.

/** CRC-32 (IEEE 802.3), the checksum the ZIP central directory carries. */
const CRC_TABLE = (() => {
  const table = new Uint32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    table[n] = c >>> 0
  }
  return table
})()

export function crc32(bytes: Uint8Array): number {
  let c = 0xffffffff
  for (let i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}

export interface ZipEntry {
  name: string
  text: string
}

function dosDateTime(d: Date): [number, number] {
  const time = (d.getHours() << 11) | (d.getMinutes() << 5) | (Math.floor(d.getSeconds() / 2) & 0x1f)
  const date = ((d.getFullYear() - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate()
  return [time & 0xffff, date & 0xffff]
}

class ByteWriter {
  private parts: Uint8Array[] = []
  length = 0

  bytes(b: Uint8Array): void {
    this.parts.push(b)
    this.length += b.length
  }

  u16(v: number): void {
    this.bytes(new Uint8Array([v & 0xff, (v >>> 8) & 0xff]))
  }

  u32(v: number): void {
    this.bytes(new Uint8Array([v & 0xff, (v >>> 8) & 0xff, (v >>> 16) & 0xff, (v >>> 24) & 0xff]))
  }

  // Uint8Array<ArrayBuffer>, not the default Uint8Array<ArrayBufferLike>: the
  // buffer is allocated right here and is never shared, and BlobPart will not
  // accept a view whose buffer might be a SharedArrayBuffer.
  concat(): Uint8Array<ArrayBuffer> {
    const out = new Uint8Array(this.length)
    let offset = 0
    for (const p of this.parts) {
      out.set(p, offset)
      offset += p.length
    }
    return out
  }
}

/**
 * Build a stored (uncompressed) ZIP archive from UTF-8 text entries.
 *
 * The UTF-8 general-purpose flag (bit 11) is set on every entry, which is what
 * makes a Polish filename survive extraction. Our filenames are deliberately
 * ASCII (plan §8) so this should never matter — it is set because an archive
 * that silently mangles a name is worse than one that refuses it, and the
 * exporter's filenames are not the only thing that might ever go in here.
 */
export function buildZip(entries: ZipEntry[], now: Date = new Date()): Uint8Array<ArrayBuffer> {
  const encoder = new TextEncoder()
  const [time, date] = dosDateTime(now)

  const local = new ByteWriter()
  const central = new ByteWriter()
  const offsets: number[] = []

  for (const entry of entries) {
    const name = encoder.encode(entry.name)
    const data = encoder.encode(entry.text)
    const sum = crc32(data)

    offsets.push(local.length)
    local.u32(0x04034b50) // local file header
    local.u16(20) // version needed
    local.u16(0x0800) // flags: UTF-8 names
    local.u16(0) // method: stored
    local.u16(time)
    local.u16(date)
    local.u32(sum)
    local.u32(data.length)
    local.u32(data.length)
    local.u16(name.length)
    local.u16(0) // extra field length
    local.bytes(name)
    local.bytes(data)

    central.u32(0x02014b50) // central directory header
    central.u16(20) // version made by
    central.u16(20) // version needed
    central.u16(0x0800)
    central.u16(0)
    central.u16(time)
    central.u16(date)
    central.u32(sum)
    central.u32(data.length)
    central.u32(data.length)
    central.u16(name.length)
    central.u16(0) // extra
    central.u16(0) // comment
    central.u16(0) // disk number start
    central.u16(0) // internal attributes
    central.u32(0) // external attributes
    central.u32(offsets[offsets.length - 1])
    central.bytes(name)
  }

  const out = new ByteWriter()
  const localBytes = local.concat()
  const centralBytes = central.concat()
  out.bytes(localBytes)
  out.bytes(centralBytes)
  out.u32(0x06054b50) // end of central directory
  out.u16(0) // this disk
  out.u16(0) // disk with central directory
  out.u16(entries.length)
  out.u16(entries.length)
  out.u32(centralBytes.length)
  out.u32(localBytes.length)
  out.u16(0) // comment length
  return out.concat()
}
