// The stored-ZIP writer behind the FTL export page's "download everything"
// button (plan §9). Plan IDs X8.21-X8.25.
//
// A malformed archive is the failure mode that would reach the venue as
// "Windows says the folder is invalid", and our own reader could not detect it,
// so the writer was checked against an independent implementation: on
// 2026-09-12 a three-file PPW1 bundle built by this module was opened with
// Python's zipfile — testzip() returned None (every CRC good), all three
// entries read back, and "PĘCZEK (0)" survived intact. That check is recorded
// here rather than automated because it needs both runtimes in one process,
// which neither test job has; re-run it by hand if the header layout changes.

import { describe, it, expect } from 'vitest'
import { buildZip, crc32 } from '../src/lib/zip'

const u8 = (s: string) => new TextEncoder().encode(s)

describe('crc32', () => {
  it('X8.21 matches the published IEEE 802.3 vectors', () => {
    // zlib.crc32(b"") == 0; zlib.crc32(b"hello") == 0x3610a686;
    // zlib.crc32(b"123456789") == 0xcbf43926 (the standard check value).
    expect(crc32(u8(''))).toBe(0)
    expect(crc32(u8('hello'))).toBe(0x3610a686)
    expect(crc32(u8('123456789'))).toBe(0xcbf43926)
  })

  it('X8.22 checksums UTF-8 bytes, not code units', () => {
    // zlib.crc32("ŁĘCKI".encode()) — a name we really do emit.
    expect(crc32(u8('ŁĘCKI'))).toBe(0xdc95731c)
  })
})

describe('buildZip', () => {
  it('X8.23 writes the local, central and end-of-directory signatures', () => {
    const zip = buildZip([{ name: 'a.xml', text: '<a/>' }])
    const dv = new DataView(zip.buffer, zip.byteOffset, zip.byteLength)
    expect(dv.getUint32(0, true)).toBe(0x04034b50)
    // End of central directory is the last 22 bytes when there is no comment.
    expect(dv.getUint32(zip.length - 22, true)).toBe(0x06054b50)
    expect(dv.getUint16(zip.length - 22 + 8, true)).toBe(1) // entries on this disk
    expect(dv.getUint16(zip.length - 22 + 10, true)).toBe(1) // entries total
  })

  it('X8.24 records one central-directory entry per file', () => {
    const zip = buildZip([
      { name: 'a.xml', text: '<a/>' },
      { name: 'b.xml', text: '<b/>' },
      { name: 'c.xml', text: '<c/>' },
    ])
    const dv = new DataView(zip.buffer, zip.byteOffset, zip.byteLength)
    expect(dv.getUint16(zip.length - 22 + 10, true)).toBe(3)
    let signatures = 0
    for (let i = 0; i + 4 <= zip.length; i++) {
      if (dv.getUint32(i, true) === 0x02014b50) signatures++
    }
    expect(signatures).toBe(3)
  })

  it('X8.25 stores content uncompressed, so the bytes are findable verbatim', () => {
    // Method 0 is the whole reason this file is short enough to audit.
    const zip = buildZip([{ name: 'x.xml', text: 'PĘCZEK (0)' }])
    const text = new TextDecoder().decode(zip)
    expect(text).toContain('PĘCZEK (0)')
    const dv = new DataView(zip.buffer, zip.byteOffset, zip.byteLength)
    expect(dv.getUint16(8, true)).toBe(0) // compression method in the local header
    expect(dv.getUint16(6, true)).toBe(0x0800) // UTF-8 filename flag
  })
})
