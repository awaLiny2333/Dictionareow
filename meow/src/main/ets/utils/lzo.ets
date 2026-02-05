/**
 * Constructed mainly by Celia Web @ 3 Feb 2026.
 * Fixes and adaptions by Liny's dictionary cat engineer!
 * */

// LZO 解压结果类型
export interface LZODecompressResult {
  success: boolean;
  data?: ArrayBuffer;
  error?: string;
}

// LZO 解压状态码枚举
export enum LZOErrorCode {
  OK = 0,
  INPUT_OVERRUN = -1,
  OUTPUT_OVERRUN = -2,
  LOOKBEHIND_OVERRUN = -3,
  EOF_FOUND = -4,
  INVALID_OPCODE = -5
}

/**
 * 纯 TypeScript 实现的 LZO1X 解压函数
 * @param inputBuffer 压缩后的 ArrayBuffer
 * @returns 解压后的 ArrayBuffer 或错误信息
 */
export function lzoDecompress(inputBuffer: ArrayBuffer): LZODecompressResult {
  const input = new Uint8Array(inputBuffer);
  const inputLength = input.length;

  // 估算输出缓冲区大小（LZO 最大膨胀率约为 1.0625x + 64）
  const initialOutputSize = inputLength + Math.floor(inputLength / 16) + 64 + 3;
  const output = new Uint8Array(initialOutputSize);

  let ip = 0; // 输入指针
  let op = 0; // 输出指针
  let state = 0; // 状态机（记录前一个操作的类型）
  let t: number; // 临时指令码

  // 主解压循环
  try {
    while (ip < inputLength) {
      t = input[ip++];

      // 处理 Literal Run（原文复制）
      if (t < 22) {
        // 短 literal
        t += 3;
        if (op + t > output.length) {
          return { success: false, error: 'OUTPUT_OVERRUN' };
        }
        if (ip + t > inputLength) {
          return { success: false, error: 'INPUT_OVERRUN' };
        }
        do {
          output[op++] = input[ip++];
        } while (--t > 0);
        state = 4;
        continue;
      }

      // 处理 Match（匹配复制）
      let m_pos = op;
      let m_len: number;

      if (t >= 22) {
        // 长 literal 或 match
        if (t < 32) {
          // 中等长度 literal
          t -= 19;
          if (op + t > output.length) {
            return { success: false, error: 'OUTPUT_OVERRUN' };
          }
          if (ip + t > inputLength) {
            return { success: false, error: 'INPUT_OVERRUN' };
          }
          do {
            output[op++] = input[ip++];
          } while (--t > 0);
          state = t === 0 ? 4 : 0;
          continue;
        }

        // 处理 match 指令
        if (t < 64) {
          // 短 match
          m_len = (t >> 2) + 3;
          m_pos -= ((t & 3) << 8) | input[ip++];
        } else if (t < 128) {
          // 中等 match
          m_len = (t >> 5) + 4;
          m_pos -= ((t & 31) << 8) | input[ip++];
        } else {
          // 长 match
          m_len = (t << 3) | (input[ip++] & 7);
          if (m_len === 0) {
            // 遇到结束标记
            break;
          }
          m_len += 7;
          m_pos -= (input[ip++] << 8) | input[ip++];
        }
      } else {
        // 极短 match（基于状态）
        m_len = 2;
        m_pos -= (t & 7) << 2;
        t = input[ip++];
        m_pos -= t >> 2;
        if (m_pos < 0 || m_pos >= op) {
          return { success: false, error: 'LOOKBEHIND_OVERRUN' };
        }
        state = state === 0 ? 0 : 4;
      }

      // 复制匹配数据
      if (op + m_len > output.length) {
        return { success: false, error: 'OUTPUT_OVERRUN' };
      }
      if (m_pos < 0 || m_pos >= op) {
        return { success: false, error: 'LOOKBEHIND_OVERRUN' };
      }

      // 逐字节复制（处理重叠区域）
      do {
        output[op] = output[m_pos];
        op++;
        m_pos++;
      } while (--m_len > 0);

      state = 0;
    }
  } catch (e) {
    return { success: false, error: `Decompression failed: ${e.message}` };
  }

  // 返回实际解压大小的 ArrayBuffer
  const resultBuffer = output.buffer.slice(0, op);
  return { success: true, data: resultBuffer };
}

// 使用示例
// const compressedData = new Uint8Array([...]); // 你的 LZO 压缩数据
// const result = lzoDecompress(compressedData.buffer);
// if (result.success) {
//     console.log('解压成功:', result.data);
// } else {
//     console.error('解压失败:', result.error);
// }