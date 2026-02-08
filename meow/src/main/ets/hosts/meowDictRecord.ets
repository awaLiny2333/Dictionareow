import { arrayBuffer2Int64BE, bufferBuffer2Int64BE, decompress } from '../utils/data';
import { buffer, fastbuffer } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { sandboxReadArrayBufferSync } from '../utils/storage';

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
    const metaDataSlice32 = sandboxReadArrayBufferSync(this.fullPath, this.globalOffset, 32)!;

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

    // let task: taskpool.Task = new taskpool.Task(calculateMetaDataSync, this.globalRawData, this.globalOffset, numBlocks);

    // let task: taskpool.Task = new taskpool.Task(calculateMetaDataSync, this.globalRawData.slice(0), this.globalOffset, numBlocks);
    // try {
    //   const res = await taskpool.execute(task) as calculateMetaDataSyncResult;
    //   this.compSizes = res.compSizes;
    //   this.decompSizes = res.decompSizes;
    //   this.compSizesCumulative = res.compSizesCumulative;
    //   this.decompSizesCumulative = res.decompSizesCumulative;
    //   this.recBlocksHeadOffset = res.recBlocksHeadOffset;
    //   this.ready = true;
    //   console.warn(`[meowDictRecord][processMetadata] taskpool.execute(task) OK!`);
    // } catch (e) {
    //   console.error(`[meowDictRecord][processMetadata] Failed: ${e}`);
    // }

    const metaDataBlockSlice = sandboxReadArrayBufferSync(this.fullPath, this.globalOffset + 32, 16 * numBlocks)!;

    // Use less RAM
    const res = calculateMetaDataSync(metaDataBlockSlice, numBlocks);
    this.compSizes = res.compSizes;
    this.decompSizes = res.decompSizes;
    this.compSizesCumulative = res.compSizesCumulative;
    this.decompSizesCumulative = res.decompSizesCumulative;
    this.recBlocksHeadOffset = res.recBlocksHeadOffset + 32 + this.globalOffset;
    this.ready = true;
    console.warn(`[meowDictRecord][processMetadata] taskpool.execute(task) OK!`);
  }

  /**
   * Gets the record entry data of a certain segment
   * @param recordOffsetStart The local offset of the start of the record. Based on the head of the record blocks.
   * @param recordOffsetEnd The local offset of the end of the record. Based on the head of the record blocks.
   * @returns The data result.
   * */
  async getRecordEntry(recordOffsetStart: number, recordOffsetEnd?: number) {
    const startRecordIdx = Math.max(0, this.findLastIndexLessThanQuery(this.decompSizesCumulative, recordOffsetStart));
    let endRecordIdx = this.numBlocks;
    if (recordOffsetEnd) {
      endRecordIdx = this.findLastIndexLessThanQuery(this.decompSizesCumulative, recordOffsetEnd);
    }
    console.log(`[meowDictRecord][getRecordEntry] Locked range: record block #${startRecordIdx} to #${endRecordIdx}`);

    // Decompress them
    let decompressed: buffer.Buffer[] = [];

    for (let index = startRecordIdx; index <= endRecordIdx; index++) {
      const startRecordGlobalOffset = this.recBlocksHeadOffset + this.compSizesCumulative[index];
      const endRecordGlobalOffset = this.recBlocksHeadOffset + this.compSizesCumulative[index + 1];
      const tag = `    [meowDictRecord][getRecordEntry][build!][${index}]`;

      const block = sandboxReadArrayBufferSync(this.fullPath, startRecordGlobalOffset, endRecordGlobalOffset - startRecordGlobalOffset)!;

      // await decompress(this.globalRawData.slice(startRecordGlobalOffset, endRecordGlobalOffset), this.decompSizes[index], tag, { type: '0' })
      await decompress(block, this.decompSizes[index], tag, { type: '0' })
        .then((arrayBuffer) => {
          try {
            decompressed.push(buffer.from(arrayBuffer));
          } catch (e) {
            console.error(`[meowDictRecord][getRecordEntry] decompressed[index-startRecordIdx] = fastbuffer.from(arrayBuffer); Failed: ${e}`);
          }
        })
        .catch((e: BusinessError) => {
          console.error(`[meowDictRecord][getRecordEntry][${index}] Failed: ${e}`);
        })
    }

    try {
      console.log(`[meowDictRecord][getRecordEntry] Length of decompressed[]: ${decompressed.length}`);

      const longBufferBuffer = buffer.concat(decompressed);
      const recordOffsetStartInBuffer = recordOffsetStart - this.decompSizesCumulative[startRecordIdx];
      let recordOffsetEndInBuffer: number | undefined;
      if (recordOffsetEnd) {
        recordOffsetEndInBuffer = recordOffsetEnd - this.decompSizesCumulative[startRecordIdx];
      }
      const bufferSlice = longBufferBuffer.subarray(recordOffsetStartInBuffer, recordOffsetEndInBuffer);

      // const result = longBufferBuffer.toString(this.globalEncoding, recordOffsetStartInBuffer, recordOffsetEndInBuffer);
      // console.log(`[meowDictRecord][getRecordEntry] Got result: ${result}`);
      return bufferSlice;

    } catch (e) {
      console.error(`[meowDictRecord][getRecordEntry] const longBufferBuffer = buffer.concat(decompressed); Failed: ${e}`);
      return undefined;
    }
  }

  /**
   * 在升序数组中查找最后一个小于目标值的元素索引
   * @param decompSizesCumulative 升序数组
   * @param query 目标值
   * @returns 最后一个小于 query 的元素的索引。如果所有元素都大于等于 query，返回 -1
   * @author Celia Web @ Feb 4 2026
   */
  private findLastIndexLessThanQuery(decompSizesCumulative: number[], query: number): number {
    let left = 0;
    let right = decompSizesCumulative.length - 1;
    let result = -1; // 初始化为-1，处理所有元素都大于等于query的情况

    while (left <= right) {
      const mid = Math.floor((left + right) / 2);

      if (decompSizesCumulative[mid] <= query) {
        // 中间值小于query，记录当前位置，并继续在右侧寻找更大的（但依然小于query的）值
        result = mid; // 更新结果为当前满足条件的索引
        left = mid + 1; // 向右半部分继续查找
      } else {
        // 中间值大于等于query，向左半部分查找
        right = mid - 1;
      }
    }

    // 循环结束时，result 保存的就是最后一个满足条件的索引
    return result;
  }
}

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
