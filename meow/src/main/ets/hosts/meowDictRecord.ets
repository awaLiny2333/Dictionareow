import { arrayBuffer2Int64BE, bufferBuffer2Int64BE, decompress } from '../utils/data';
import { buffer, fastbuffer } from '@kit.ArkTS';

export class meowDictRecord {
  globalRawData: ArrayBuffer;
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

  constructor(globalOffset: number, globalRawData: ArrayBuffer, globalEncoding: string) {
    this.globalOffset = globalOffset;
    this.globalRawData = globalRawData;
    this.globalEncoding = globalEncoding;
    this.processMetaData();
  }

  private processMetaData() {
    // Number items in record_blocks. Does not need to equal the number of keyword blocks. Big-endian.
    let numBlocks = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 0, this.globalOffset + 8));
    if (numBlocks !== undefined) {
      console.log(`[meowDictRecord][processMetadata] numBlocks: ${numBlocks}`);
    } else {
      console.error(`[meowDictRecord][processMetadata] numBlocks is empty??? What is going on here?`);
      numBlocks = 0;
    }
    this.numBlocks = numBlocks;

    // Total number of records in dictionary. Should be equal to keyword_sect.num_entries. Big-endian.
    this.numEntries = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 8, this.globalOffset + 16)) || 0;

    // Total size of the comp_size[i] and decomp_size[i] variables, in bytes. In other words, should equal 16 times num_blocks. Big-endian.
    this.indexLen = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 16, this.globalOffset + 24)) || 0;

    // Total size of the rec_block[i] sections, in bytes. Big-endian.
    this.blocksLen = arrayBuffer2Int64BE(this.globalRawData.slice(this.globalOffset + 24, this.globalOffset + 32)) || 0;

    try {
      const bufferBufferRawData = buffer.from(this.globalRawData);
      let sumCompSize = 0;
      let sumDecompSize = 0;
      let readCompDecompIndex = 0;
      for (readCompDecompIndex = 0; readCompDecompIndex < this.numBlocks; readCompDecompIndex++) {
        this.compSizesCumulative.push(sumCompSize);
        this.decompSizesCumulative.push(sumDecompSize);

        const localOffset = 32 + readCompDecompIndex * 8 * 2;
        const compSizeOffset = localOffset + this.globalOffset;
        const decompSizeOffset = localOffset + this.globalOffset + 8;

        const compSize = bufferBuffer2Int64BE(bufferBufferRawData, compSizeOffset) || 0;
        const decompSize = bufferBuffer2Int64BE(bufferBufferRawData, decompSizeOffset) || 0;
        sumCompSize += compSize;
        sumDecompSize += decompSize;
        this.compSizes.push(compSize);
        this.decompSizes.push(decompSize);
        // console.log(`[meowDictRecord][processMetadata][${readCompDecompIndex}] compSize = ${compSize}, decompSize = ${decompSize}, decompSizeOffset = ${decompSizeOffset}`);
      }

    } catch (e) {
      console.error(`[meowDictRecord][processMetadata] read compSizes[] and decompSizes[] failed! ${e}`);
    }

    this.recBlocksHeadOffset = this.globalOffset + 32 + 16 * numBlocks;
    console.warn(`[meowDictRecord][processMetadata] recBlocksHeadOffset = ${this.recBlocksHeadOffset}`);
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
      let startRecordGlobalOffset = this.recBlocksHeadOffset + this.compSizesCumulative[index];
      let endRecordGlobalOffset = this.recBlocksHeadOffset + this.compSizesCumulative[index + 1];
      await decompress(this.globalRawData.slice(startRecordGlobalOffset, endRecordGlobalOffset), this.decompSizes[index], '    [meowDictRecord][getRecordEntry][build!]').then((arrayBuffer) => {
        try {
          decompressed.push(buffer.from(arrayBuffer));
        } catch (e) {
          console.error(`[meowDictRecord][getRecordEntry] decompressed[index-startRecordIdx] = buffer.from(arrayBuffer); Failed: ${e}`);
        }
      })
    }

    console.log(`[meowDictRecord][getRecordEntry] Length of decompressed: ${decompressed.length}`);

    try {
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
