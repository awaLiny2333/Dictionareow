import { meowDictHeader } from './meowDictHeader';
import { arrayBuffer2Int32BE, arrayBuffer2Int32LE, arrayBuffer2UTF16LE, getUnitEncodingLength } from '../utils/data';
import { meowDictKeyword } from './meowDictKeyword';
import { alder32ChecksumVerify } from '../utils/alder32';
import { meowDictRecord } from './meowDictRecord';
import { readArrayBufferSync } from '../utils/storage';
import { fileIo } from '@kit.CoreFileKit';
import { fastbuffer } from '@kit.ArkTS';

export enum meowDictType {
  MDD = 0,
  MDX = 1,
}

@ObservedV2
export class meowDict {
  fullPath: string;
  size: number = -1;
  type: meowDictType;
  @Trace header: meowDictHeader | undefined;
  keyword: meowDictKeyword | undefined;
  @Trace record: meowDictRecord | undefined;

  constructor(type: meowDictType, fullPath: string) {
    this.fullPath = fullPath;
    this.type = type;

    // Get size
    try {
      this.size = fileIo.statSync(fullPath).size;
    } catch (e) {
      console.error(`[meowDict][${this.fullPath}] fileIo.statSync(fullPath) failed: ${e}`);
    }
  }

  // Build

  init() {
    const startTime: number = Date.now();

    let globalOffset: number = 0;
    return this.processHeader().then((val) => {
      globalOffset += val;
      globalOffset += this.processKeyword(globalOffset);
      this.processRecord(globalOffset);

      // Ending mark
      console.log(`[meowDict][${this.fullPath}] READY! (${Date.now() - startTime} ms)`);
    })
  }

  /**
   * Process the header section
   * @returns The length of header section (in bytes).
   * */
  private async processHeader() {
    const startTime: number = Date.now();

    const block04 = readArrayBufferSync(this.fullPath!, 0, 4);
    const headerContentLength = arrayBuffer2Int32BE(block04) || 0;

    const headerContentBuffer = readArrayBufferSync(this.fullPath!, 4, headerContentLength);
    const headerContent = arrayBuffer2UTF16LE(headerContentBuffer);

    const headerChecksumBuffer = readArrayBufferSync(this.fullPath!, 4 + headerContentLength, 4);
    const headerChecksumNumber = arrayBuffer2Int32LE(headerChecksumBuffer) || 0;

    if (headerContent) {
      this.header = meowDictHeader.fromXMLString(headerContent, this.fullPath);
      console.log(`[meowDict][processHeader] Header converted: ${'\n'}${this.header.toXMLString()}`);
    } else {
      console.error(`[meowDict][processHeader] Header is empty??? What is going on here?`);
    }

    if (this.type == meowDictType.MDD) {
      // Use UTF-16
      if (this.header) {
        this.header.Encoding = 'utf-16le';
        console.warn(`[meowDict][processHeader] Is MDD! Use utf-16le! UnitLength = ${getUnitEncodingLength(this.header.Encoding)}`);
      }
    }

    const verify = alder32ChecksumVerify(headerContentBuffer, headerChecksumNumber);
    if (verify) {
      console.log(`[meowDict][processHeader] Checksum verify: ${verify}`);
    } else {
      console.warn(`[meowDict][processHeader] Checksum verify: ${verify}`);
    }

    console.log(`[meowDict][processHeader] Header total length: ${8 + headerContentLength} (${Date.now() - startTime} ms)`);
    return 8 + headerContentLength;
  }

  /**
   * Process the keyword section
   * @returns The length of keyword section (in bytes).
   * */
  private processKeyword(baseBytesOffset: number) {
    const startTime: number = Date.now();

    const type1Encrypted = this.header!.Encrypted == '1';
    const type2Encrypted = this.header!.Encrypted == '2';

    if (type1Encrypted) {
      this.keyword = new meowDictKeyword(baseBytesOffset, this.fullPath!, this.header!, true, false);
    } else if (type2Encrypted) {
      this.keyword = new meowDictKeyword(baseBytesOffset, this.fullPath!, this.header!, false, true);
    } else {
      // Not encrypted
      this.keyword = new meowDictKeyword(baseBytesOffset, this.fullPath!, this.header!, false, false);
    }

    console.log(`[meowDict][processKeyword] Keyword OK! Total length: ${44 + this.keyword.keyIndexCompLen + this.keyword.keyBlocksLen} (${Date.now() - startTime} ms)`);
    return 44 + this.keyword.keyIndexCompLen + this.keyword.keyBlocksLen; // THIS NEEDS FURTHER CARE // I think this is correct.
  }

  /**
   * Process the record section
   * */
  private processRecord(baseBytesOffset: number) {
    const startTime: number = Date.now();

    this.record = new meowDictRecord(baseBytesOffset, this.fullPath!, this.header!.Encoding);
    console.log(`[meowDict][processRecord] Record OK! (${Date.now() - startTime} ms)`);
  }

  // Use

  /**
   * Look up a key in the dictionary
   * @param key The key
   * @returns The ArrayBuffer of content
   * */
  async lookUpKey(key: string, exact: boolean) {
    if (!this.isReady()) {
      console.warn(`[meowDictHeader][lookUpWord] Rejected. Uninitialized!`);
      return undefined;
    }

    key = key.replace(/\0/g, '').replace(/\UFEFF/g, '');

    return this.keyword!.lookUpRecordEntryOffset(key, exact).then(async (offsets) => {
      if (offsets !== null && offsets !== undefined) {
        let arrayBuffers: ArrayBuffer[] = [];
        for (let index = 0; index < offsets.length; index++) {
          console.log(`[meowDict][lookUpWord][${key}][${index + 1}/${offsets.length}] Get entry!`);
          let buf: ArrayBuffer | undefined = undefined;
          if (offsets[index][1] < 0) {
            // The last word in the entire dictionary?!
            buf = await this.record!.getRecordEntry(offsets[index][0], undefined, key + ' <end>')
          } else {
            buf = await this.record!.getRecordEntry(offsets[index][0], offsets[index][1], key);
          }
          let isNew = true;

          try {
            if (this.type == meowDictType.MDX && buf && buf.byteLength < 1000) {
              const fastBuf = fastbuffer.from(buf);
              for (let index = 0; index < arrayBuffers.length; index++) {
                if (arrayBuffers[index].byteLength < 1000) {
                  if (fastBuf.equals(fastbuffer.from(arrayBuffers[index]))) {
                    isNew = false;
                  }
                }
              }
            }
          } catch (e) {
            console.error(`[meowDict][lookUpWord] Compare equal and eliminate duplication failed: ${e}`);
          }

          if (buf && isNew) {
            arrayBuffers.push(buf);
          }
        }
        return arrayBuffers;
      } else {
        console.warn(`[meowDict][lookUpWord] this.keyword!.lookUpRecordEntryOffset(word) is null or undefined??`);
        return undefined;
      }
    });
  }

  /**
   * Nearly the same with lookUpKey method.
   * @param key The key
   * @returns The ArrayBuffer of content
   * */
  jumpTo(key: string) {
    if (!this.isReady()) {
      console.warn(`[meowDictHeader][lookUpWord] Rejected. Uninitialized!`);
      return undefined;
    }

    key = key.replace(/\0/g, '').replace(/\UFEFF/g, '');

    return this.keyword!.jumpToExactRecordEntryOffset(key).then((offsets) => {
      if (offsets !== null && offsets !== undefined) {
        if (offsets[1] < 0) {
          // The last word in the entire dictionary?!
          return this.record!.getRecordEntry(offsets[0], undefined, key + ' <end>').then((buf) => {
            return buf;
          })
        }
        return this.record!.getRecordEntry(offsets[0], offsets[1], key).then((buf) => {
          return buf;
        })
      } else {
        console.warn(`[meowDict][lookUpWord] this.keyword!.lookUpRecordEntryOffset(word) is null or undefined??`);
        return undefined;
      }
    })
  }

  /**
   * Checks if the dictionary has this key
   * @param key The key
   * @returns The ArrayBuffer of content
   * */
  hasKey(key: string, exact: boolean) {
    if (!this.isReady()) {
      console.warn(`[meowDictHeader][lookUpWord] Rejected. Uninitialized!`);
      return undefined;
    }

    key = key.replace(/\0/g, '').replace(/\UFEFF/g, '');

    return this.keyword!.lookUpRecordEntryOffset(key, exact, false).then((offsets) => {
      return (offsets !== null && offsets !== undefined);
    })
  }

  /**
   * Checks if the dictionary is ready
   * @returns A boolean
   * */
  isReady() {
    if (!this.header || !this.keyword || !this.record) {
      return false;
    }
    if (!this.keyword.index) {
      return false;
    }
    if (!this.record.ready) {
      return false;
    }
    return true;
  }
}

