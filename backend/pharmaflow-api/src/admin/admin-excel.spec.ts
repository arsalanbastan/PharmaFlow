import { inflateRawSync } from 'node:zlib';
import { buildXlsx } from './admin-excel';

function readZipEntry(file: Buffer, expectedName: string): Buffer {
  let offset = 0;

  while (offset + 30 <= file.length) {
    const signature = file.readUInt32LE(offset);
    if (signature !== 0x04034b50) {
      break;
    }

    const compressionMethod = file.readUInt16LE(offset + 8);
    const compressedSize = file.readUInt32LE(offset + 18);
    const nameLength = file.readUInt16LE(offset + 26);
    const extraLength = file.readUInt16LE(offset + 28);
    const nameStart = offset + 30;
    const dataStart = nameStart + nameLength + extraLength;
    const dataEnd = dataStart + compressedSize;
    const name = file.subarray(nameStart, nameStart + nameLength).toString('utf8');

    if (name === expectedName) {
      const compressed = file.subarray(dataStart, dataEnd);
      if (compressionMethod === 0) {
        return compressed;
      }
      if (compressionMethod === 8) {
        return inflateRawSync(compressed);
      }
      throw new Error(`Unsupported ZIP compression method: ${compressionMethod}`);
    }

    offset = dataEnd;
  }

  throw new Error(`ZIP entry not found: ${expectedName}`);
}

describe('admin Excel export', () => {
  it('builds a real XLSX container with Persian text and inline strings', () => {
    const file = buildXlsx(
      'دارو و کالا',
      ['نام', 'قیمت'],
      [
        ['آموکسی‌سیلین', 125000],
        ['=1+1', 0],
      ],
    );

    expect(file.subarray(0, 2).toString('ascii')).toBe('PK');

    const workbook = readZipEntry(file, 'xl/workbook.xml').toString('utf8');
    const worksheet = readZipEntry(file, 'xl/worksheets/sheet1.xml').toString(
      'utf8',
    );

    expect(workbook).toContain('دارو و کالا');
    expect(worksheet).toContain('آموکسی‌سیلین');
    expect(worksheet).toContain('<t xml:space="preserve">=1+1</t>');
    expect(worksheet).not.toContain('<f>1+1</f>');
  });
});
