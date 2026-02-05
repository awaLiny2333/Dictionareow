import { meowDictHeader } from './meowDictHeader';
import { arrayBuffer2Int32BE, arrayBuffer2Int32LE, arrayBuffer2UTF16LE, getUnitEncodingLength } from '../utils/data';
import { meowDictKeyword } from './meowDictKeyword';
import { alder32ChecksumVerify } from '../utils/alder32';
import { meowDictRecord } from './meowDictRecord';

export enum meowDictType {
  MDD = 0,
  MDX = 1,
}

@ObservedV2
export class meowDict {
  type: meowDictType;
  @Trace rawData: ArrayBuffer | undefined;
  @Trace header: meowDictHeader | undefined;
  keyword: meowDictKeyword | undefined;
  record: meowDictRecord | undefined;

  constructor(type: meowDictType, rawData?: ArrayBuffer) {
    this.type = type;
    this.rawData = rawData;

    if (rawData) {
      this.init();
    }
  }

  init() {
    let globalOffset: number = 0;
    globalOffset += this.processHeader();
    globalOffset += this.processKeyword(globalOffset);
    this.processRecord(globalOffset);

    // Ending mark
    console.log(`[meowDict][${this.type}] READY!
    `);
  }

  /**
   * Process the header section
   * @returns The length of header section (in bytes).
   * */
  private processHeader() {
    let headerContentLength = arrayBuffer2Int32BE(this.rawData!.slice(0, 4)) || 0;

    const headerContentBuffer = this.rawData!.slice(4, 4 + headerContentLength);
    let headerContent = arrayBuffer2UTF16LE(headerContentBuffer);

    const headerChecksumBuffer = this.rawData!.slice(4 + headerContentLength, 4 + headerContentLength + 4);
    const headerChecksumNumber = arrayBuffer2Int32LE(headerChecksumBuffer) || 0;

    // Header checksum in ADLER32, let's leave it here for a while
    // TODO: finish up the checksum checker

    if (headerContent) {
      this.header = meowDictHeader.fromXMLString(headerContent);
      // console.log(`[meowDictHeader][processHeader] Header converted: ${'\n'}${this.header.toXMLString()}`);
    } else {
      console.error(`[meowDictHeader][processHeader] Header is empty??? What is going on here?`);
    }

    if (this.type == meowDictType.MDD) {
      // Use UTF-16
      if (this.header) {
        this.header.Encoding = 'utf-16le';
        console.warn(`[meowDictHeader][processHeader] Is MDD! Use utf-16le! UnitLength = ${getUnitEncodingLength(this.header.Encoding)}`);
      }
    }

    const verify = alder32ChecksumVerify(headerContentBuffer, headerChecksumNumber);
    if (verify) {
      console.log(`[meowDictHeader][processHeader] Checksum verify: ${verify}`);
    } else {
      console.warn(`[meowDictHeader][processHeader] Checksum verify: ${verify}`);
    }

    console.log(`[meowDictHeader][processHeader] Header total length: ${8 + headerContentLength}`);
    return 8 + headerContentLength;
  }

  /**
   * Process the keyword section
   * @returns The length of keyword section (in bytes).
   * */
  private processKeyword(baseBytesOffset: number) {
    this.keyword = new meowDictKeyword(baseBytesOffset, this.rawData!, this.header!.Encoding);
    return 44 + this.keyword.keyIndexCompLen + this.keyword.keyBlocksLen; // THIS NEEDS FURTHER CARE // I think this is correct.
  }

  /**
   * Process the record section
   * */
  private processRecord(baseBytesOffset: number) {
    this.record = new meowDictRecord(baseBytesOffset, this.rawData!, this.header!.Encoding);
  }

  /**
   * Look up a key in the dictionary
   * @param key The key
   * @returns The ArrayBuffer of content
   * */
  async lookUpKey(key: string, fuzzyInclusive: boolean = false) {
    if (!(this.keyword && this.keyword.index && this.header && this.record)) {
      console.warn(`[meowDictHeader][lookUpWord] Rejected. Uninitialized!`);
      return;
    }

    return this.keyword!.lookUpRecordEntryOffset(key, fuzzyInclusive).then(async (offsets) => {
      if (offsets !== null && offsets !== undefined) {
        if (offsets[1] < 0) {
          // The last word in the entire dictionary?!
          return await this.record!.getRecordEntry(offsets[0]);
        }
        return await this.record!.getRecordEntry(offsets[0], offsets[1]);
      } else {
        console.warn(`[meowDict][lookUpWord] this.keyword!.lookUpRecordEntryOffset(word) is null or undefined??`);
        return undefined;
      }
    });
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
    return true;
  }
}