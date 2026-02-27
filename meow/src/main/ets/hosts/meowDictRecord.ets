import { arrayBuffer2Int64BE, bufferBuffer2Int64BE, decompress, findLastIndexLessThanQuery } from '../utils/data';
import { fastbuffer, taskpool } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { readArrayBufferConcurrent, readArrayBufferSync } from '../utils/storage';

@ObservedV2
export class meowDictRecord {
  fullPath: string;
  globalOffset: number; // The offset from the head of the entire raw data.
  globalEncoding: string;
  numBlocks: number = 0;
  numEntries: number = 0;
  indexLen: number = 0;
  blocksLen: number = 0;
  compSizes: number[] = [];
  decompSizes: number[] = [];
  compSizesCumulative: number[] = []; // Actually is equivalent the local offset
  decompSizesCumulative: number[] = [];
  recBlocksHeadOffset: number = 0;
  @Trace ready: boolean = false;

  constructor(globalOffset: number, fullPath: string, globalEncoding: string) {
    this.globalOffset = globalOffset;
    this.fullPath = fullPath;
    this.globalEncoding = globalEncoding;
    this.processMetaData();
  }

  private async processMetaData() {
    const metaDataSlice32 = readArrayBufferSync(this.fullPath, this.globalOffset, 32)!;

    // Number items in record_blocks. Does not need to equal the number of keyword blocks. Big-endian.
    let numBlocks = arrayBuffer2Int64BE(metaDataSlice32.slice(0, 8));
    if (numBlocks !== undefined) {
      console.log(`[meowDictRecord][processMetadata] numBlocks: ${numBlocks}`);
    } else {
      console.error(`[meowDictRecord][processMetadata] numBlocks is empty??? What is going on here?`);
      numBlocks = 0;
    }
    this.numBlocks = numBlocks;

    // Total number of records in dictionary. Should be equal to keyword_sect.num_entries. Big-endian.
    this.numEntries = arrayBuffer2Int64BE(metaDataSlice32.slice(8, 16)) || 0;

    // Total size of the comp_size[i] and decomp_size[i] variables, in bytes. In other words, should equal 16 times num_blocks. Big-endian.
    this.indexLen = arrayBuffer2Int64BE(metaDataSlice32.slice(16, 24)) || 0;

    // Total size of the rec_block[i] sections, in bytes. Big-endian.
    this.blocksLen = arrayBuffer2Int64BE(metaDataSlice32.slice(24, 32)) || 0;

    const metaDataBlockSlice = readArrayBufferSync(this.fullPath, this.globalOffset + 32, 16 * numBlocks)!;

    calculateMetaDataConcurrent(metaDataBlockSlice, numBlocks).then((res) => {
      res = res as calculateMetaDataSyncResult;
      this.compSizes = res.compSizes;
      this.decompSizes = res.decompSizes;
      this.compSizesCumulative = res.compSizesCumulative;
      this.decompSizesCumulative = res.decompSizesCumulative;
      this.recBlocksHeadOffset = res.recBlocksHeadOffset + 32 + this.globalOffset;
      this.ready = true;
    })
  }

  // Use

  /**
   * Gets the record entry data of a certain segment
   * @param recordOffsetStart The local offset of the start of the record. Based on the head of the record blocks.
   * @param recordOffsetEnd The local offset of the end of the record. Based on the head of the record blocks.
   * @returns The data result.
   * */
  getRecordEntry(recordOffsetStart: number, recordOffsetEnd?: number, key = '') {
    const startRecordIdx = Math.max(0, findLastIndexLessThanQuery(this.decompSizesCumulative, recordOffsetStart));

    // Decompress them
    const startRecordGlobalOffset = this.recBlocksHeadOffset + this.compSizesCumulative[startRecordIdx];
    const endRecordGlobalOffset = this.recBlocksHeadOffset + this.compSizesCumulative[startRecordIdx + 1];
    const tag = `    [meowDictRecord][getRecordEntry][build!][${key}][${startRecordIdx}]`;
    const readableLength = endRecordGlobalOffset - startRecordGlobalOffset;

    // const block = sandboxReadArrayBufferSync(this.fullPath, startRecordGlobalOffset, endRecordGlobalOffset - startRecordGlobalOffset)!;
    return readArrayBufferConcurrent(this.fullPath, startRecordGlobalOffset, readableLength).then((block) => {
      return decompress(block!, this.decompSizes[startRecordIdx], tag, { type: '0' })
        .then((arrayBuffer) => {
          const recordOffsetStartInBuffer = recordOffsetStart - this.decompSizesCumulative[startRecordIdx];
          let recordOffsetEndInBuffer: number | undefined;
          if (recordOffsetEnd) {
            recordOffsetEndInBuffer = recordOffsetEnd - this.decompSizesCumulative[startRecordIdx];
          }
          const arrayBufferSliceA = arrayBuffer.slice(recordOffsetStartInBuffer, recordOffsetEndInBuffer);

          if (recordOffsetEnd) {
            const expectedLength = recordOffsetEnd - recordOffsetStart;
            const endRecordIdx = Math.max(0, findLastIndexLessThanQuery(this.decompSizesCumulative, recordOffsetEnd));
            if (startRecordIdx != endRecordIdx) {
              console.warn(`    [meowDictRecord][getRecordEntry][end][${key}][${endRecordIdx}] Cross block! exp=${expectedLength}, act=${readableLength}`);
            }
          }

          return arrayBufferSliceA;
        })
        .catch((e: BusinessError) => {
          console.error(`[meowDictRecord][getRecordEntry][${startRecordIdx}] Failed: ${e}`);
          return undefined;
        })
    })
  }
}

// MetaData processing

interface calculateMetaDataSyncResult {
  compSizes: number[];
  decompSizes: number[];
  compSizesCumulative: number[]; // Actually is equivalent the local offset
  decompSizesCumulative: number[];
  recBlocksHeadOffset: number;
}

@Concurrent
function calculateMetaDataSync(rawData: ArrayBuffer, numBlocks: number) {
  const startTime: number = Date.now();

  let compSizes: number[] = [];
  let decompSizes: number[] = [];
  let compSizesCumulative: number[] = []; // Actually is equivalent the local offset
  let decompSizesCumulative: number[] = [];

  try {
    const bufferBufferRawData = fastbuffer.from(rawData);

    let sumCompSize = 0;
    let sumDecompSize = 0;
    let readCompDecompIndex = 0;

    // TODO: find a way to optimize this sequential process of record block info
    for (readCompDecompIndex = 0; readCompDecompIndex < numBlocks; readCompDecompIndex++) {
      compSizesCumulative.push(sumCompSize);
      decompSizesCumulative.push(sumDecompSize);

      const localOffset = readCompDecompIndex * 16;
      const compSizeOffset = localOffset;
      const decompSizeOffset = localOffset + 8;

      const compSize = bufferBuffer2Int64BE(bufferBufferRawData, compSizeOffset) || 0;
      const decompSize = bufferBuffer2Int64BE(bufferBufferRawData, decompSizeOffset) || 0;
      sumCompSize += compSize;
      sumDecompSize += decompSize;
      compSizes.push(compSize);
      decompSizes.push(decompSize);
      // console.log(`[meowDictRecord][processMetadata][${readCompDecompIndex}] compSize = ${compSize}, decompSize = ${decompSize}, decompSizeOffset = ${decompSizeOffset}`);
    }
    compSizesCumulative.push(sumCompSize);
    decompSizesCumulative.push(sumDecompSize);
  } catch (e) {
    console.error(`[meowDictRecord][calculateMetaDataSync] read compSizes[] and decompSizes[] failed! ${e}`);
  }

  let recBlocksHeadOffset = 16 * numBlocks;
  console.warn(`[meowDictRecord][calculateMetaDataSync] OK! recBlocksHeadOffset = ${recBlocksHeadOffset} (${Date.now() - startTime} ms)`);

  return {
    compSizes: compSizes,
    decompSizes: decompSizes,
    compSizesCumulative: compSizesCumulative,
    decompSizesCumulative: decompSizesCumulative,
    recBlocksHeadOffset: recBlocksHeadOffset,
  } as calculateMetaDataSyncResult;
}

async function calculateMetaDataConcurrent(rawData: ArrayBuffer, numBlocks: number) {
  // taskpool.execute(task)
  let task: taskpool.Task = new taskpool.Task(calculateMetaDataSync, rawData, numBlocks);

  try {
    const result = await taskpool.execute(task);
    console.info(`[calculateMetaDataConcurrent] taskpool.execute(task)!`);
    return result as calculateMetaDataSyncResult;
  } catch (e) {
    console.error(`[calculateMetaDataConcurrent] Failed: ${e}`);
    return undefined;
  }
  // return undefined;
}
