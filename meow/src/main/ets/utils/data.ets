import { buffer, fastbuffer } from '@kit.ArkTS';
import lazy { lzoDecompress } from './lzo';
import lazy { zlib } from '@kit.BasicServicesKit';
import { alder32ChecksumVerify } from './alder32';
import { decryptKeywordIndex, getEncryptionKey } from './decryption';

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

export function arrayBuffer2Int64BE(rawData: ArrayBuffer | undefined) {
  try {
    let result = fastbuffer.from(rawData).readBigInt64BE();
    // console.log(`[arrayBuffer2BigInt64BE] result is ${result}, Number(result) is ${Number(result)}`);
    return Number(result);
  } catch (e) {
    console.error(`[arrayBuffer2BigInt64BE] Read failed: ${e}`);
    return undefined;
  }
}

export function arrayBuffer2Int32LE(rawData: ArrayBuffer | undefined) {
  try {
    let result = fastbuffer.from(rawData).readInt32LE();
    // console.log(`[arrayBuffer2Int32LE] result is ${result}`);
    return result;
  } catch (e) {
    console.error(`[arrayBuffer2Int32LE] Read failed: ${e}`);
    return undefined;
  }
}

export function arrayBuffer2Int32BE(rawData: ArrayBuffer | undefined) {
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

export function arrayBuffer2UTF16LE(rawData: ArrayBuffer | undefined) {
  try {
    let result = fastbuffer.from(rawData).toString('ucs-2');
    // console.log(`[arrayBuffer2UTF16LE] result is ${result}`);
    return result;
  } catch (e) {
    console.error(`[arrayBuffer2UTF16LE] Read failed: ${e}`);
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
  // [^\p{L}\p{N}_] 匹配任何非字母、非数字且非下划线的字符
  return str.replace(/[^\p{L}\p{N}_@]/gu, '');
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

/**
 * Analyses a ResourceStr and converts it to a string object.
 * @param resourceStr A Resource, indicating the identifier of the ResourceStr.
 * @returns A string, the string content retrieved.
 * @example resource_to_string($r('app.string.Whats_new_content_1'))
 * */
export function resource_to_string(resourceStr: Resource, context: Context) {
  try {
    return context.resourceManager.getStringSync(resourceStr.id);
  } catch (error) {
    console.error('[resource_to_string] ' + error);
    return 'meow Error!';
  }
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

export interface decompressDecryptConfig {
  type: string;
  regCode?: string;
  userId?: string;
}

export async function decompress(rawData: ArrayBuffer, decompLen: number, logTag: string = '', dec: decompressDecryptConfig, verify: boolean = false) {
  const compType = new Uint8Array(rawData.slice(0, 4)).toString();
  console.log(`${logTag}[decompress] compType = ${compType}, compLen = ${rawData.byteLength}, decompLen = ${decompLen}`);

  const compChecksumBuffer = rawData.slice(4, 8);

  let compData = rawData.slice(8);
  // console.log(`${logTag}[decompress] compData.byteLength = ${compData.byteLength}`);

  if (dec.type == '2') {
    console.log(`${logTag} Type 2 encryption! Decrypting...`);
    const compKey = getEncryptionKey(compChecksumBuffer);
    compData = decryptKeywordIndex(new Uint8Array(compData), new Uint8Array(compKey));
    console.log(`${logTag}[decompress][type2Decrypted] compData.byteLength = ${compData.byteLength}`);
  }

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

  if (verify) {
    const compChecksumNumber = arrayBuffer2Int32BE(compChecksumBuffer) || 0;
    const verifyResult = alder32ChecksumVerify(decompData, compChecksumNumber);
    if (verifyResult) {
      console.log(`${logTag}[decompress] Checksum verify: ${verifyResult}`);
    } else {
      console.warn(`${logTag}[decompress] Checksum verify: ${verifyResult}`);
    }
  }

  return decompData;
}

// Other

/**
 * Adds a unit to a size in bytes.
 * @param size_in_bytes A number or bigint, the size in bytes.
 * @returns A string, the connected result of a number of size and its unit.
 * */
export function addUnitsToSize(size_in_bytes: number | bigint) {
  if (size_in_bytes == undefined || size_in_bytes == null) {
    return 'No Bytes!';
  }
  let units = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
  let result = BigInt(size_in_bytes);
  let unit = 0;
  while (result > 1000 * 1000 && unit < units.length - 2) {
    result /= 1000n;
    unit += 1;
  }
  // To keep decimal places
  let numberResult = Number(result);
  numberResult /= 1000;
  unit += 1;
  return numberResult.toFixed(2) + " " + units[unit];
}

/**
 * 根据文件名或路径获取对应的 MIME 类型。
 * @description
* 1. 自动处理大小写（如 .JPG -> image/jpeg）。
 * 2. 能够正确处理包含路径的字符串（如 /path/to/file.txt）。
 * 3. 排除无后缀或隐藏文件（如 .gitignore）。
 * 4. 匹配失败时默认返回 'application/octet-stream'。
 * @param {string} fileName - 文件名或完整路径 (例如: "image.png" 或 "/home/user/data.json")
 * @returns {string} 对应的 MIME 类型字符串
 * @author Gemini web @ Feb 8 2026
 * @example
* mimeOfFileName('vacation.jpg');     // 'image/jpeg'
 * mimeOfFileName('INDEX.HTML');      // 'text/html'
 * mimeOfFileName('config');          // 'application/octet-stream'
 * mimeOfFileName('.hidden-file');    // 'application/octet-stream'
 */
export function mimeOfFileName(fileName: string): string {
  if (!fileName) {
    return 'application/octet-stream';
  }

  // 1. 只取文件名部分，防止路径中的点号干扰 (例如 /path.to/my-file)
  const baseName = fileName.split(/[\\/]/).pop() || '';

  // 2. 提取后缀名
  const lastDotIndex = baseName.lastIndexOf('.');

  // 如果点号不存在，或者点号在开头（如 .gitignore），通常视为无后缀
  if (lastDotIndex <= 0) {
    return 'application/octet-stream';
  }

  const ext = baseName.slice(lastDotIndex + 1).toLowerCase();

  // 3. 扩展后的 MIME 映射表
  const mimeMap: Record<string, string> = {
    // 文本
    'txt': 'text/plain',
    'html': 'text/html',
    'htm': 'text/html',
    'css': 'text/css',
    'csv': 'text/csv',
    'xml': 'application/xml',

    // 脚本 & 数据
    'js': 'application/javascript',
    'mjs': 'application/javascript',
    'ts': 'text/typescript',
    'json': 'application/json',
    'yaml': 'text/yaml',
    'yml': 'text/yaml',

    // 图片
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'svg': 'image/svg+xml',
    'webp': 'image/webp',
    'ico': 'image/x-icon',

    // 视频 & 音频
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'ogg': 'video/ogg',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'flac': 'audio/flac',

    // 文档
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',

    // 压缩包
    'zip': 'application/zip',
    'rar': 'application/x-rar-compressed',
    '7z': 'application/x-7z-compressed',
    'gz': 'application/gzip',
    'tar': 'application/x-tar',
  };

  return mimeMap[ext] || 'application/octet-stream';
}