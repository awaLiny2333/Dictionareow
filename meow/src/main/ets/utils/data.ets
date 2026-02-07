import { buffer, fastbuffer } from '@kit.ArkTS';
import { lzoDecompress } from './lzo';
import { zlib } from '@kit.BasicServicesKit';
import { alder32ChecksumVerify } from './alder32';

export interface meowWrapHtmlOptions {
  title?: string;
  charset?: string;
  language?: string;
  includeMeta?: boolean;
  styles?: string;
  scripts?: string;
}

// Numbers

export function bufferBuffer2Int64BE(rawData: buffer.Buffer | fastbuffer.FastBuffer, offset: number) {
  try {
    let result = rawData.readBigInt64BE(offset);
    // console.log(`[arrayBuffer2BigInt64BE] result is ${result}, Number(result) is ${Number(result)}`);
    return Number(result);
  } catch (e) {
    console.error(`[bufferBuffer2Int64BE] Read failed: ${e}`);
    return undefined;
  }
}

export function arrayBuffer2Int64BE(rawData: ArrayBuffer) {
  try {
    let result = fastbuffer.from(rawData).readBigInt64BE();
    // console.log(`[arrayBuffer2BigInt64BE] result is ${result}, Number(result) is ${Number(result)}`);
    return Number(result);
  } catch (e) {
    console.error(`[arrayBuffer2BigInt64BE] Read failed: ${e}`);
    return undefined;
  }
}

export function arrayBuffer2Int32LE(rawData: ArrayBuffer) {
  try {
    let result = fastbuffer.from(rawData).readInt32LE();
    // console.log(`[arrayBuffer2Int32LE] result is ${result}`);
    return result;
  } catch (e) {
    console.error(`[arrayBuffer2Int32LE] Read failed: ${e}`);
    return undefined;
  }
}

export function arrayBuffer2Int32BE(rawData: ArrayBuffer) {
  try {
    let result = fastbuffer.from(rawData).readInt32BE();
    // console.log(`[arrayBuffer2Int32BE] result is ${result}`);
    return result;
  } catch (e) {
    console.error(`[arrayBuffer2Int32BE] Read failed: ${e}`);
    return undefined;
  }
}

export function bufferBuffer2Int16BE(rawData: buffer.Buffer | fastbuffer.FastBuffer, offset: number) {
  try {
    let result = rawData.readInt16BE(offset);
    // console.log(`[bufferBuffer2Int16BE] result is ${result}`);
    return result;
  } catch (e) {
    console.error(`[bufferBuffer2Int16BE] Read failed: ${e}`);
    return undefined;
  }
}

// Strings

export function arrayBuffer2UTF16LE(rawData: ArrayBuffer) {
  try {
    let result = fastbuffer.from(rawData).toString('ucs-2');
    // console.log(`[arrayBuffer2UTF16LE] result is ${result}`);
    return result;
  } catch (e) {
    console.error(`[arrayBuffer2UTF16LE] Read failed: ${e}`);
    return undefined;
  }
}

export function bufferBuffer2UTF8(rawData: buffer.Buffer | fastbuffer.FastBuffer, offset: number, end: number) {
  try {
    let result = rawData.toString('utf-8', offset, end);
    // console.log(`[arrayBuffer2UTF8] result is ${result}`);
    return result;
  } catch (e) {
    console.error(`[bufferBuffer2UTF8] Read failed: ${e}`);
    return undefined;
  }
}

export function bufferBuffer2String(rawData: buffer.Buffer | fastbuffer.FastBuffer, offset: number, end: number, encoding: string) {
  try {
    let result = rawData.toString(encoding, offset, end);
    // console.log(`[bufferBuffer2String] result is ${result}`);
    return result;
  } catch (e) {
    console.error(`[bufferBuffer2String] Read failed: ${e}`);
    return undefined;
  }
}

/**
 * 检查目标字符串是否按字母顺序位于两个边界字符串之间（包含边界）
 * @param target 要检查的目标字符串
 * @param lowerBound 下界字符串
 * @param upperBound 上界字符串
 * @returns 如果 target 在 [lowerBound, upperBound] 区间内返回 true，否则返回 false
 * @author Celia Web @ Feb 4 2026
 */
export function isStringBetween(target: string, lowerBound: string, upperBound: string): boolean {
  // const options: Intl.CollatorOptions = { sensitivity: 'accent' };
  // return target.localeCompare(lowerBound, 'en', options) >= 0 && target.localeCompare(upperBound, 'en', options) <= 0;
  return target >= lowerBound && target <= upperBound;
}

/**
 * 删掉所有非字母数字的字符
 * @param str 源字符串
 * @returns 处理后的字符串
 * */
export function keepOnlyAlphanumericGlobal(str: string): string {
  // [^\p{L}\p{N}] 匹配任何非字母（任何语言）和非数字的字符
  return str.replace(/[^\p{L}\p{N}]/gu, '');
}

/**
 * 将内容包装成完整的 HTML 文档
 * @param content 要包装的 HTML 内容（可以是纯文本或包含 HTML 标签）
 * @param options 配置选项
 * @returns 完整的 HTML 文档字符串
 * @author DeepSeek @ 3 Feb 2026
 */
export function wrapHtml(content: string = '', options: meowWrapHtmlOptions = {
  title: 'Document',
  charset: 'utf-8',
  language: 'zh-cn',
  includeMeta: true,
  styles: '',
  scripts: ''
}): string {
  // 基本 HTML 结构
  return `<!DOCTYPE html>
<html lang="${options.language}">
<head>
    <meta charset="${options.charset}">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    ${options.includeMeta ? '<meta http-equiv="X-UA-Compatible" content="IE=edge">' : ''}
    <title>${options.title}</title>
    ${options.styles ? `<style>${options.styles}</style>` : ''}
</head>
<body>
    <div id="content">
        ${content}
    </div>
    ${options.scripts ? `<script>${options.scripts}</script>` : ''}
</body>
</html>`;
}

// ArrayBuffers

/**
 * Returns true if the buffer is all zero
 * @param buffer The buffer
 * @returns Boolean
 * @author HarmonyOS Developers Search AI @ Feb 4 2026
 * */
export function isArrayBufferZero(buffer: ArrayBuffer): boolean {
  const view = new Uint8Array(buffer);
  return view.every(byte => byte === 0);
}

/**
 * Returns true if the uint8array is all zero
 * @param ui8a The uint8array
 * @returns Boolean
 * */
export function isUint8ArrayZero(ui8a: Uint8Array): boolean {
  return ui8a.every(byte => byte === 0);
}

const encodingUnitLengthsMap = new Map<string, number>([
  ['ascii', 1],
  ['latin1', 1],
  ['binary', 1],
  ['iso-8859-1', 1],
  ['utf-8', 1],
  ['utf8', 1],
  ['ucs2', 2],
  ['ucs-2', 2],
  ['utf16', 2],
  ['utf-16', 2],
  ['utf16le', 2],
  ['utf-16le', 2],
  ['utf16be', 2],
  ['utf-16be', 2],
  ['utf32', 4],
  ['utf-32', 4],
]);

/**
 * 使用 Map 获取编码长度
 * @param encoding 编码名称
 * @returns 字节数或 null
 * @author Celia Web @ Feb 4 2026
 */
export function getUnitEncodingLength(encoding: string): number {
  return encodingUnitLengthsMap.get(encoding) || 1;
}


// Compressed

export async function decompress(rawData: ArrayBuffer, decompLen: number, logTag: string = '') {
  const compType = new Uint8Array(rawData.slice(0, 4)).toString();
  console.log(`${logTag}[decompress] compType = ${compType}, compLen = ${rawData.byteLength}, decompLen = ${decompLen}`);

  const compChecksumBuffer = rawData.slice(4, 8);
  const compChecksumNumber = arrayBuffer2Int32BE(compChecksumBuffer) || 0;

  const compData = rawData.slice(8);
  console.log(`${logTag}[decompress] compData.byteLength = ${compData.byteLength}`);


  let decompData: ArrayBuffer = new ArrayBuffer(0);
  if (compType == '0,0,0,0') {
    // No compression.
    decompData = compData;
    console.error(`${logTag}[decompress] chunk uncompressed!`);

  } else if (compType == '1,0,0,0') {
    // LZO
    // TODO: Verify if this LZO algorithm works
    let lzoResult = lzoDecompress(compData);
    if (lzoResult.success) {
      decompData = lzoResult.data!;
    } else {
      console.error(`${logTag}[decompress] LZO Failed: ${lzoResult.error}`);
      decompData = new ArrayBuffer(0);
    }

  } else if (compType == '2,0,0,0') {
    // ZLIB
    decompData = new ArrayBuffer(decompLen);

    // let lastFour = compData.slice(compData.byteLength - 4, compData.byteLength); // Last four bytes of compData
    // console.warn(`${logTag}[decompress] Checksum early verify of zlib feature: ${arrayBuffer2Int32BE(lastFour) == arrayBuffer2Int32BE(compChecksumBuffer)}`);

    let zip = zlib.createZipSync();
    await zip.uncompress(decompData, compData).catch((e: BusinessError) => {
      console.error(`${logTag}[decompress] zlib uncompress failed: ${e}`);
    })
  }

  const verify = alder32ChecksumVerify(decompData, compChecksumNumber);
  if (verify) {
    console.log(`${logTag}[decompress] Checksum verify: ${verify}`);
  } else {
    console.warn(`${logTag}[decompress] Checksum verify: ${verify}`);
  }
  return decompData;
}