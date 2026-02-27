/**
 * Constructed mainly by Celia Web @ 3 Feb 2026.
 * Fixes and adaptions by Liny's dictionary cat engineer!
 * */

import { arrayBuffer2Int32BE, arrayBuffer2Int32LE } from "./data";

export class Adler32 {
  private static readonly BASE: number = 65521;
  private a: number = 1;
  private b: number = 0;

  constructor() {
    this.reset();
  }

  /**
   * 重置计算器状态，开始一次新的计算。
   */
  public reset(): void {
    this.a = 1;
    this.b = 0;
  }

  /**
   * 更新校验和，传入 ArrayBuffer 类型的数据。
   * @param buf 需要计算校验和的数据缓冲区
   */
  public update(buf: ArrayBuffer): void {
    const data = new Uint8Array(buf);
    let a = this.a;
    let b = this.b;
    let len = data.length;

    // 优化：每循环约 5552 次才进行一次取模运算（参考 zlib 的 NMAX 定义）
    const nmax = 5552;
    let i = 0;

    while (len > 0) {
      const k = len < nmax ? len : nmax;
      const remaining = len - k;

      for (let j = 0; j < k; j++) {
        a += data[i++];
        b += a;
      }

      a %= Adler32.BASE;
      b %= Adler32.BASE;
      len = remaining;
    }

    this.a = a;
    this.b = b;
  }

  /**
   * 获取最终的 Adler-32 校验和。
   * @returns 计算出的 32 位校验和
   */
  public digest(): number {
    return (this.b << 16) | this.a;
  }

  /**
   * 静态方法：一次性计算 ArrayBuffer 的 Adler-32 校验和。
   * @param buf 需要计算校验和的数据缓冲区
   * @returns 计算出的 32 位校验和
   */
  public static checksum(buf: ArrayBuffer): number {
    const adler = new Adler32();
    adler.update(buf);
    return adler.digest();
  }
}

// 使用示例：
// const data = new Uint8Array([87, 105, 107, 105, 112, 101, 100, 105, 97]).buffer;
// const checksum = Adler32.checksum(data);
// console.log(checksum.toString(16)); // 输出 Wikipedia 字符串的 Adler-32 值：11e60398

export function alder32ChecksumVerify(dataBuffer: ArrayBuffer | undefined, checksumNumber: number) {
  if (!dataBuffer) {
    return false;
  }
  const calcChecksum = Adler32.checksum(dataBuffer);
  return calcChecksum == checksumNumber;
}
