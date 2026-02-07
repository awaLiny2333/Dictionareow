import {
  arrayBuffer2Int32BE,
  arrayBuffer2Int64BE,
  bufferBuffer2Int16BE,
  bufferBuffer2Int64BE,
  bufferBuffer2String,
  decompress,
  getUnitEncodingLength,
  isStringBetween,
  isUint8ArrayZero,
  keepOnlyAlphanumericGlobal as keepOnlyAlphanumeric
} from '../utils/data';
import { buffer, taskpool } from '@kit.ArkTS';

export class meowDictKeyword {
  globalRawData: ArrayBuffer;
  globalOffset: number; // The offset from the head of the entire raw data.
  globalEncoding: string;
  numBlocks: number = 0;
  numEntries: number = 0;
  keyIndexDecompLen: number = 0;
  keyIndexCompLen: number = 0;
  keyBlocksLen: number = 0;
  headerChecksum: number = 0;
  index: meowDictKeywordIndex | undefined;
  lookUpBlockIndex: number = 0;

  constructor(globalOffset: number, globalRawData: ArrayBuffer, globalEncoding: string) {
    this.globalOffset = globalOffset;
    this.globalRawData = globalRawData;
    this.globalEncoding = globalEncoding;
    this.processMetadata();
    this.processIndex();
  }

  private processMetadata() {
    // Number of items in key_blocks. Big-endian. Possibly encrypted, see below.
    let numBlocks = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 0, this.globalOffset + 8));
    if (numBlocks !== undefined) {
      console.log(`[meowDictKeyword][processMetadata] numBlocks: ${numBlocks}`);
    } else {
      console.error(`[meowDictKeyword][processMetadata] numBlocks is empty??? What is going on here?`);
      numBlocks = 0;
    }

    // Don't care about encryption and move on first.
    // TODO: Work on encryption and decryption

    // Total number of keywords. Big-endian. Possibly encrypted, see below.
    let numEntries = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 8, this.globalOffset + 16)) || 0;

    // Number of bytes in decompressed version of key_index. Big-endian. Possibly encrypted, see below.
    let keyIndexDecompLen = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 16, this.globalOffset + 24)) || 0;

    // Number of bytes in compressed version of key_index (including the comp_type and checksum parts). Big-endian. Possibly encrypted, see below.
    let keyIndexCompLen = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 24, this.globalOffset + 32)) || 0;

    // Number of bytes in compressed version of key_index (including the comp_type and checksum parts). Big-endian. Possibly encrypted, see below.
    let keyBlocksLen = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 32, this.globalOffset + 40)) || 0;

    // ADLER32 checksum of the preceding 40 bytes. If those are encrypted, it is the checksum of the decrypted version. Big-endian.
    let headerChecksum = arrayBuffer2Int32BE(this.globalRawData.slice(this.globalOffset + 40, this.globalOffset + 44)) || 0;

    console.log(`[meowDictKeyword] Meta data for Keyword Section: numBlocks = ${numBlocks}, numEntries = ${numEntries}, keyIndexDecompLen = ${keyIndexDecompLen}, ` +
      `keyIndexCompLen = ${keyIndexCompLen}, keyBlocksLen = ${keyBlocksLen}, headerChecksum = ${headerChecksum}`);

    this.numBlocks = numBlocks;
    this.numEntries = numEntries;
    this.keyIndexDecompLen = keyIndexDecompLen;
    this.keyIndexCompLen = keyIndexCompLen;
    this.keyBlocksLen = keyBlocksLen;
    this.headerChecksum = headerChecksum;
  }

  private processIndex() {
    const startTime = Date.now();
    let index = new meowDictKeywordIndex(this.globalOffset + 44, this.globalRawData, this.keyIndexDecompLen, this.keyIndexCompLen, this.numBlocks);
    index.init(this.globalEncoding).then(() => {
      this.index = index;
      console.log(`[meowDictKeyword][Index][init] Index loaded! Used time ${Date.now() - startTime} ms!`);
    })
  }

  /**
   * Gets the offset of a specific record entry of given key.
   * @param key The key
   * @param fuzzyInclusive Allow case and punctuation fuzzy
   * @returns [offsetStart, offsetEnd] local offsets with head of record as base
   * */
  async lookUpRecordEntryOffset(key: string, fuzzyInclusive: boolean = false) {
    if (!this.index) {
      console.warn(`[meowDictKeyword][Index][lookUp] Index uninitialized. Request rejected.`);
      return undefined;
    }
    const startTime = Date.now();

    for (let lookUpBlockIndex = 0; lookUpBlockIndex < this.numBlocks; lookUpBlockIndex++) {
      const theBlockEntry = this.index.indexEntries[lookUpBlockIndex];
      const firstWord = theBlockEntry.firstWord;
      const lastWord = theBlockEntry.lastWord;

      if (isStringBetween(key, firstWord, lastWord)) {
        console.log(`[meowDictKeyword][Index][lookUp] Selected index block from '${firstWord}' to '${lastWord}'! Looking into this index block!`);
        this.lookUpBlockIndex = lookUpBlockIndex;

        return this.getKeyBlockArrayBuffer(lookUpBlockIndex).then((block) => {
          if (!block) {
            console.error(`[meowDictKeyword][Index][lookUp] this.getKeyBlockArrayBuffer(lookUpBlockIndex) returned undefined. What's going on here?`);
            return undefined;
          }

          let offset = this.findOffsetByKeyword(key, block.keywords, block.offsets, fuzzyInclusive);
          if (offset === null) {
            console.warn(`[meowDictKeyword][Index][lookUp] Key '${key}' not found!`);
          } else {
            console.warn(`[meowDictKeyword][Index][lookUp] Found key '${key}', offset = [${offset}], used time ${(Date.now() - startTime)} ms!`);
          }
          return offset;

        })
      } else {
        if (lookUpBlockIndex < 10) {
          console.log(`[meowDictKeyword][Index][lookUp][${lookUpBlockIndex}] Passed block from '${firstWord}' to '${lastWord}'.`);
        } else {
          if (lookUpBlockIndex % 10 == 0) {
            console.log(`[meowDictKeyword][Index][lookUp][${lookUpBlockIndex}] Passed block from '${firstWord}' to '${lastWord}'.`);
          }
        }
      }
    }

    console.warn(`[meowDictKeyword][Index][lookUp] Key '${key}' not found in any of the blocks!`);
    return undefined;
  }

  private async getKeyBlockArrayBuffer(indexInBlocks: number) {
    if (!this.index) {
      console.warn(`[meowDictKeyword][Index][getKeyBlockArrayBuffer] Index uninitialized. Request rejected.`);
      return undefined;
    }

    if (this.index.indexEntries[indexInBlocks].builtBlock) {
      console.log(`[meowDictKeyword][Index][getKeyBlockArrayBuffer] Index entry block built! The built block directly returned!`);
      return this.index.indexEntries[indexInBlocks].builtBlock;
    }

    console.warn(`[meowDictKeyword][Index][getKeyBlockArrayBuffer] Begin to build KeywordBlock!`);

    let offsetFromRawHead = this.globalOffset + 44 + this.keyIndexCompLen;
    for (let index = 0; index < indexInBlocks; index++) {
      offsetFromRawHead += this.index.indexEntries[index].compSize;
    }

    const thisBlockCompSize = this.index.indexEntries[indexInBlocks].compSize;
    const thisBlockDecompSize = this.index.indexEntries[indexInBlocks].decompSize;

    console.log(`[meowDictKeyword][Index][getKeyBlockArrayBuffer] offsetFromRawHead = ${offsetFromRawHead}, thisBlockCompSize = ${thisBlockCompSize}, thisBlockDecompSize = ${thisBlockDecompSize}`);

    const compBlock = this.globalRawData.slice(offsetFromRawHead, offsetFromRawHead + thisBlockCompSize);
    return decompress(compBlock, thisBlockDecompSize, '[meowDictKeyword][Index][getKeyBlockArrayBuffer]').then((decompBlock) => {
      const block = new meowDictKeywordBlock();
      return block.init(decompBlock, this.globalEncoding).then(() => {
        this.index!.indexEntries[indexInBlocks].builtBlock = block;
        return block;
      })
    });
  }

  /**
   * 使用二分查找在平行数组中搜索关键词的 offset start 和 end
   *
   * 此处的 offset 理应是以 block head 为 base 的 local offset
   * @param target 目标关键词
   * @param keywords 存储关键词的数组（必须已排序）
   * @param offsets 存储偏移量的平行数组
   * @returns 找到则返回对应的 offset (number)，否则返回 null
   * @author Gemini 3 @ Feb 4 2026
   */
  private findOffsetByKeyword(target: string, keywords: string[], offsets: number[], fuzzyInclusive: boolean = false): number[] | null {
    // const options: Intl.CollatorOptions = { sensitivity: 'accent' };
    if (fuzzyInclusive) {
      target = keepOnlyAlphanumeric(target.toLowerCase());
    }

    let left = 0;
    let right = keywords.length - 1;

    while (left <= right) {
      // 使用 Math.floor 防止浮点数，并避免 (left + right) 可能的溢出
      let mid = left + Math.floor((right - left) / 2);

      let midValue: string;
      if (fuzzyInclusive) {
        midValue = keepOnlyAlphanumeric(keywords[mid]).toLowerCase();
      } else {
        midValue = keywords[mid];
      }
      console.log(`[meow] Compared ${keywords[mid]} (${midValue})`)

      if (midValue === target) {
        // 找到匹配项，返回对应的平行 offset

        if (fuzzyInclusive) {
          while (mid - 1 > 0 && keepOnlyAlphanumeric(keywords[mid-1]).toLowerCase() === target) {
            mid -= 1;
          } // choose the first match

          if (mid == keywords.length - 1) {
            // Is the last one
            return [offsets[mid], -1];
          }

          const offsetStart = offsets[mid];

          while (mid + 1 < keywords.length && keepOnlyAlphanumeric(keywords[mid+1]).toLowerCase() === target) {
            mid += 1;
          } // find the last match

          if (mid == keywords.length - 1) {
            // Is the last one
            return [offsetStart, -1];
          }

          const offsetEnd = offsets[mid+1];

          return [offsetStart, offsetEnd];

        } else {

          if (mid == keywords.length - 1) {
            // Is the last one
            return [offsets[mid], -1];
          }
          return [offsets[mid], offsets[mid+1]];
        }

      } else if (midValue < target) {
        // } else if (target.localeCompare(midValue, 'en', options) > 0) {
        // 目标在右半部分
        left = mid + 1;
      } else {
        // 目标在左半部分
        right = mid - 1;
      }
    }

    // 未找到目标
    return null;
  }
}

export class meowDictKeywordIndex {
  rawData: ArrayBuffer;
  offset: number; // The offset from the head of the entire raw data.
  keyIndexCompLen: number;
  keyIndexDecompLen: number;
  decompData: ArrayBuffer;
  numBlocks: number;
  indexEntries: meowDictKeywordIndexEntry[] = [];

  constructor(offset: number, rawData: ArrayBuffer, keyIndexDecompLen: number, keyIndexCompLen: number, numBlocks: number) {
    this.offset = offset;
    this.rawData = rawData;
    this.keyIndexCompLen = keyIndexCompLen;
    this.keyIndexDecompLen = keyIndexDecompLen;
    this.numBlocks = numBlocks;
    this.decompData = new ArrayBuffer(keyIndexDecompLen);
    // this.init();
  }

  async init(encoding: string) {
    this.decompData = await decompress(this.rawData.slice(this.offset, this.offset + this.keyIndexCompLen), this.keyIndexDecompLen, '[meowDictKeyword][Index][init]');
    this.processIndexEntry(encoding);
  }

  processIndexEntry(encoding: string) {
    this.indexEntries = [];
    let offset = 0;
    // console.log(`[meowDictKeyword][IndexEntry] Offset starts with: ${offset}`);
    try {
      const bufferBuffer = buffer.from(this.decompData);

      for (let index = 0; index < this.numBlocks; index++) {
        let entry = new meowDictKeywordIndexEntry(bufferBuffer, encoding, offset);
        offset += (entry.firstSize + entry.lastSize + 2) * getUnitEncodingLength(encoding) + 28;
        // console.log(`[meowDictKeyword][IndexEntry] Offset pushed to: ${offset}`);
        this.indexEntries.push(entry);
      }
    } catch (e) {
      console.error(`[meowDictKeyword][Index][init][processIndexEntry] Failed: ${e}`);
    }

  }
}

export class meowDictKeywordIndexEntry {
  numEntries: number;
  firstSize: number;
  firstWord: string;
  lastSize: number;
  lastWord: string;
  compSize: number;
  decompSize: number;
  builtBlock: meowDictKeywordBlock | undefined;

  constructor(bufferBuffer: buffer.Buffer, encoding: string, offset: number) {

    let ul = getUnitEncodingLength(encoding); // 1 byte for UTF-8
    // console.warn(`[meowDictKeyword][IndexEntry] encoding = ${encoding}, encodingUnitLength = ${ul}`);

    // Number of keywords in the first keyword block.
    this.numEntries = bufferBuffer2Int64BE(bufferBuffer, offset) || 0;

    // Length of first_word[0], not including trailing null character. In number of “basic units” for the encoding
    // so e.g. bytes for UTF-8, and 2-byte units for UTF-16.
    this.firstSize = bufferBuffer2Int16BE(bufferBuffer, offset + 8) || 0;

    // The first keyword (alphabetically) in the key_blocks[0] keyword block. Encoding given by Encoding attribute in the header.
    // this.firstWord = arrayBuffer2UTF8(arrayBuffer.slice(10, 10 + this.firstSize)) || '';
    this.firstWord = bufferBuffer2String(bufferBuffer, offset + 10, offset + 10 + ul * this.firstSize, encoding) || '';

    const lastBaseOffset = 12 + ul * this.firstSize + ul; // No meaning. Just to make things shorter

    // Length of last_word[0], not including trailing null character. In number of “basic units” for the encoding
    // so e.g. bytes for UTF-8, and 2-byte units for UTF-16.
    this.lastSize = bufferBuffer2Int16BE(bufferBuffer, offset + 10 + ul * this.firstSize + ul) || 0;

    // The last keyword (alphabetically) in the key_blocks[0] keyword block. Encoding given by Encoding attribute in the header.
    // this.lastWord = arrayBuffer2UTF8(arrayBuffer.slice(12 + encodingUnitLength + this.firstSize, 12 + encodingUnitLength + this.firstSize + this.lastSize)) || '';

    this.lastWord = bufferBuffer2String(bufferBuffer, offset + lastBaseOffset, offset + lastBaseOffset + ul * this.lastSize, encoding) || '';

    // Compressed size of key_blocks[0].
    this.compSize = bufferBuffer2Int64BE(bufferBuffer, offset + lastBaseOffset + ul * this.lastSize + ul) || 0;

    // Decompressed size of key_blocks[0].
    this.decompSize = bufferBuffer2Int64BE(bufferBuffer, offset + lastBaseOffset + ul * this.lastSize + ul + 8) || 0;

    // console.log(`[meowDictKeyword][IndexEntry] Constructed: numEntries = ${this.numEntries}, firstSize = ${this.firstSize}, firstWord = ${this.firstWord}, ` +
    //   `lastSize = ${this.lastSize}, lastWord = ${this.lastWord}, compSize = ${this.compSize}, decompSize = ${this.decompSize}`);
    // console.log(`[meowDictKeyword][IndexEntry] ${buffer.from(arrayBuffer.slice(0, 14 + this.firstSize + this.lastSize + 16))}`);
  }
}

interface meowDictKeywordBlockSplitBuildResult {
  offsets: number[];
  keywords: string[];
}

@Concurrent
function splitBuild(rawData: ArrayBuffer, encoding: string) {
  const startTime = Date.now();
  const uintData = new Uint8Array(rawData);

  let buildOffsets: number[] = [];
  let buildKeywords: string[] = [];

  let encodingUnitLength = getUnitEncodingLength(encoding); // 1 byte for UTF-8
  let pointer = 0;
  try {
    const rawDataBufferBuffer = buffer.from(rawData);

    while (pointer < rawData.byteLength) {
      const offsetNumber = bufferBuffer2Int64BE(rawDataBufferBuffer, pointer) || 0;
      buildOffsets.push(offsetNumber);

      pointer += 8; // Now points at the start of the string
      const startOfString = pointer;

      while (!isUint8ArrayZero(uintData.subarray(pointer, pointer + encodingUnitLength))) {
        pointer += encodingUnitLength;
      }
      const endOfString = pointer;

      const keyword = bufferBuffer2String(rawDataBufferBuffer, startOfString, endOfString, encoding) || '';
      buildKeywords.push(keyword);

      // console.log(`[meowDictKeyword][IndexBlock][splitBuild] offsetNumber = ${offsetNumber}, keyword = ${keyword}`);

      pointer += encodingUnitLength; // Skip null char
    }
  } catch (e) {
    console.error(`[meowDictKeyword][IndexBlock][splitBuild] failed: ${e}`);
  }

  console.log(`[meowDictKeyword][IndexBlock][splitBuild] Used time ${Date.now() - startTime} ms.`);
  return { offsets: buildOffsets, keywords: buildKeywords } as meowDictKeywordBlockSplitBuildResult;
}

export class meowDictKeywordBlock {
  // private rawData: ArrayBuffer;
  offsets: number[] = [];
  keywords: string[] = [];

  async init(rawData: ArrayBuffer, encoding: string) {
    let task: taskpool.Task = new taskpool.Task(splitBuild, rawData, encoding);
    try {
      const res = await taskpool.execute(task) as meowDictKeywordBlockSplitBuildResult;
      console.info(`[meowDictKeywordBlock][init] taskpool.execute(task)!`);
      this.offsets = res.offsets;
      this.keywords = res.keywords;
      return true;
    } catch (e) {
      console.error(`[meowDictKeywordBlock][init] Failed: ${e}`);
      return false;
    }
  }
}
