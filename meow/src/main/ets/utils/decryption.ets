/**
 * Constructed mainly by Gemini Web @ 7 Feb 2026.
 * Fixes and adaptions by Liny's dictionary cat engineer!
 * */

import { buffer } from '@kit.ArkTS';

/**
 * Salsa20/8 加密/解密类
 * 特点：使用 128-bit Key, 64-bit IV (全0), 8 轮变换
 * @author Gemini @ Feb 7 2026
 */
export class Salsa20_8 {
  private static SIGMA = [0x616c6574, 0x32342d6b, 0x696e6720, 0x65206279];

  private static qr(x: Uint32Array, a: number, b: number, c: number, d: number): void {
    let v = 0;
    v = (x[a] + x[d]) | 0;
    x[b] ^= (v << 7) | (v >>> 25);
    v = (x[b] + x[a]) | 0;
    x[c] ^= (v << 9) | (v >>> 23);
    v = (x[c] + x[b]) | 0;
    x[d] ^= (v << 13) | (v >>> 19);
    v = (x[d] + x[c]) | 0;
    x[a] ^= (v << 18) | (v >>> 14);
  }

  public static process(data: Uint8Array, key: Uint8Array): Uint8Array {
    const state = new Uint32Array(16);
    const working = new Uint32Array(16);

    // 矩阵填充 (128-bit Key)
    state[0] = Salsa20_8.SIGMA[0];
    state[1] = key[0] | (key[1] << 8) | (key[2] << 16) | (key[3] << 24);
    state[2] = key[4] | (key[5] << 8) | (key[6] << 16) | (key[7] << 24);
    state[3] = key[8] | (key[9] << 8) | (key[10] << 16) | (key[11] << 24);
    state[4] = key[12] | (key[13] << 8) | (key[14] << 16) | (key[15] << 24);
    state[5] = Salsa20_8.SIGMA[1];
    state[6] = 0;
    state[7] = 0; // IV = 0
    state[8] = 0;
    state[9] = 0; // Counter = 0
    state[10] = Salsa20_8.SIGMA[2];
    state[11] = state[1];
    state[12] = state[2];
    state[13] = state[3];
    state[14] = state[4];
    state[15] = Salsa20_8.SIGMA[3];

    const out = new Uint8Array(data.length);
    const ks = new Uint8Array(64);
    const ksView = new DataView(ks.buffer);

    for (let i = 0; i < data.length; i += 64) {
      working.set(state);
      for (let r = 0; r < 8; r += 2) {
        // Column rounds
        Salsa20_8.qr(working, 0, 4, 8, 12);
        Salsa20_8.qr(working, 5, 9, 13, 1);
        Salsa20_8.qr(working, 10, 14, 2, 6);
        Salsa20_8.qr(working, 15, 3, 7, 11);
        // Row rounds
        Salsa20_8.qr(working, 0, 1, 2, 3);
        Salsa20_8.qr(working, 5, 6, 7, 4);
        Salsa20_8.qr(working, 10, 11, 8, 9);
        Salsa20_8.qr(working, 15, 12, 13, 14);
      }

      for (let j = 0; j < 16; j++) {
        ksView.setUint32(j * 4, (working[j] + state[j]) | 0, true);
      }

      state[8] = (state[8] + 1) | 0;
      if (state[8] === 0) {
        state[9] = (state[9] + 1) | 0;
      }

      for (let j = 0; j < 64 && (i + j) < data.length; j++) {
        out[i + j] = data[i + j] ^ ks[j];
      }
    }
    return out;
  }
}

/**
 * RIPEMD-128 完整实现 (ArrayBuffer 输入输出)
 */
class RIPEMD128Binary {
  private h = new Uint32Array([0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476]);

  private readonly rL = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8, 3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12, 1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2];
  private readonly rR = [5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12, 6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2, 15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13, 8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14];
  private readonly sL = [11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8, 7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12, 11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5, 11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12];
  private readonly sR = [8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6, 9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11, 9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5, 15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8];
  private readonly KL = [0x00000000, 0x5a827999, 0x6ed9eba1, 0x8f1bbcdc];
  private readonly KR = [0x50a28be6, 0x5c4dd124, 0x6d703ef3, 0x00000000];

  private f(j: number, x: number, y: number, z: number): number {
    if (j < 16) return x ^ y ^ z;
    if (j < 32) return (x & y) | (~x & z);
    if (j < 48) return (x | ~y) ^ z;
    return (x & z) | (y & ~z);
  }

  private rotl(x: number, n: number): number {
    return (x << n) | (x >>> (32 - n));
  }

  public digest(input: ArrayBuffer): ArrayBuffer {
    const bytes = new Uint8Array(input);
    const words = this.preprocess(bytes);

    for (let i = 0; i < words.length; i += 16) {
      const block = words.subarray(i, i + 16);
      let GeneratedDestructArray_1 = [this.h[0], this.h[1], this.h[2], this.h[3]];
      let al = GeneratedDestructArray_1[0];
      let bl = GeneratedDestructArray_1[1];
      let cl = GeneratedDestructArray_1[2];
      let dl = GeneratedDestructArray_1[3];
      let GeneratedDestructArray_2 = [this.h[0], this.h[1], this.h[2], this.h[3]];
      let ar = GeneratedDestructArray_2[0];
      let br = GeneratedDestructArray_2[1];
      let cr = GeneratedDestructArray_2[2];
      let dr = GeneratedDestructArray_2[3];

      for (let j = 0; j < 64; j++) {
        // 左路径
        let tl = (al + this.f(j, bl, cl, dl) + block[this.rL[j]] + this.KL[j >> 4]) | 0;
        al = dl; dl = cl; cl = bl;
        bl = this.rotl(tl, this.sL[j]);

        // 右路径
        let tr = (ar + this.f(63 - j, br, cr, dr) + block[this.rR[j]] + this.KR[j >> 4]) | 0;
        ar = dr; dr = cr; cr = br;
        br = this.rotl(tr, this.sR[j]);
      }

      const t = (this.h[1] + cl + dr) | 0;
      this.h[1] = (this.h[2] + dl + ar) | 0;
      this.h[2] = (this.h[3] + al + br) | 0;
      this.h[3] = (this.h[0] + bl + cr) | 0;
      this.h[0] = t;
    }

    // 转换为小端序 ArrayBuffer 输出
    const result = new ArrayBuffer(16);
    const view = new DataView(result);
    for (let i = 0; i < 4; i++) {
      view.setUint32(i * 4, this.h[i], true);
    }
    return result;
  }

  private preprocess(bytes: Uint8Array): Uint32Array {
    const bitLen = bytes.length * 8;
    // 计算填充后的总字节数 (必须是 64 的倍数)
    const newByteLen = (((bytes.length + 8) >> 6) + 1) << 6;
    const buffer = new ArrayBuffer(newByteLen);
    const u8 = new Uint8Array(buffer);

    u8.set(bytes);
    u8[bytes.length] = 0x80; // 补 1

    const view = new DataView(buffer);
    // 在最后 8 字节写入原始位长度 (小端序)
    view.setUint32(newByteLen - 8, bitLen, true);
    // 处理大长度情况（虽然位运算 32 位限制了总量，但保持结构完整）
    view.setUint32(newByteLen - 4, Math.floor(bitLen / 0x100000000), true);

    const words = new Uint32Array(newByteLen / 4);
    for (let i = 0; i < words.length; i++) {
      words[i] = view.getUint32(i * 4, true);
    }
    return words;
  }
}

/**
 * 封装导出函数
 */
function ripemd128Binary(buffer: ArrayBuffer): ArrayBuffer {
  return new RIPEMD128Binary().digest(buffer);
}

export function decryptMDXBlock(encryptedBlock: ArrayBuffer, userId: string, regCodeHex: string): ArrayBuffer {
  // 1. 数据准备
  const encryptedBytes = new Uint8Array(encryptedBlock);
  const regCodeBytes = new Uint8Array(
    regCodeHex.match(/.{1,2}/g)!.map(byte => parseInt(byte, 16))
  );

  // 2. 生成 User ID 的哈希 (128-bit)
  const userIdHash = new Uint8Array(ripemd128Binary(buffer.from(userId, 'ascii').buffer));

  // 3. 解密 RegCode 以获取 Master Key Hash
  // 根据伪代码：reg_code 是被 userIdHash 加密的 masterKeyHash
  const masterKeyHash = Salsa20_8.process(regCodeBytes, userIdHash);

  // 4. 使用 Master Key Hash 解密原始块
  const decryptedBytes = Salsa20_8.process(encryptedBytes, masterKeyHash);

  return decryptedBytes.buffer;
}

/**
 * 核心：计算 ripemd128(checksum + "\x95\x36\x00\x00")
 * @param checksum 输入的 ArrayBuffer 校验和
 * @returns 16 字节的加密 Key (ArrayBuffer)
 */
export function getEncryptionKey(checksum: ArrayBuffer): ArrayBuffer {
  // 1. 准备后缀字节: \x95\x36\x00\x00
  const suffix = new Uint8Array([0x95, 0x36, 0x00, 0x00]);

  // 2. 拼接 checksum 和 suffix
  const combined = new Uint8Array(checksum.byteLength + suffix.length);
  combined.set(new Uint8Array(checksum), 0);
  combined.set(suffix, checksum.byteLength);

  // 3. 调用之前实现的算法 (这里使用刚才定义的 RIPEMD128Binary 类)
  return ripemd128Binary(combined.buffer as ArrayBuffer);
}

/**
 * 解密 Keyword Index 块
 * @param buf 被加密的压缩数据 (Uint8Array)
 * @param key 通过 ripemd128(checksum + "\x95\x36\x00\x00") 生成的密钥
 */
export function decryptKeywordIndex(buf: Uint8Array, key: Uint8Array) {
  const buflen = buf.length;
  const keylen = key.length;

  // 初始化 previous 值为 0x36
  let previous = 0x36;
  let currentByte = 0;
  let temp = 0;

  for (let i = 0; i < buflen; i++) {
    // 1. 记录当前字节（这是下一轮的 previous）
    currentByte = buf[i];

    // 2. 执行 SWAPNIBBLE (与加密相同，高低位互换)
    // (byte >> 4) | (byte << 4) & 0xFF
    temp = ((currentByte >> 4) | (currentByte << 4)) & 0xFF;

    // 3. 逆向 XOR 操作
    // 原始：buf[i] = SWAPNIBBLE(plain ^ i ^ key ^ prev)
    // 解密：plain = SWAPNIBBLE(buf[i]) ^ i ^ key ^ prev
    buf[i] = (temp ^ (i & 0xFF) ^ key[i % keylen] ^ previous) & 0xFF;

    // 4. 更新 previous 为加密时的字节（即解密前保存的值）
    previous = currentByte;
  }
  return buf.buffer as ArrayBuffer;
}