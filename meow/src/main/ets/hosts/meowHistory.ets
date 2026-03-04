import { readArrayBufferConcurrent, saveHybrid } from '../utils/storage';
import { fastbuffer } from '@kit.ArkTS';

@ObservedV2
export class meowHistory {
  limit: number = 233;
  @Trace data: string[] = [];
  fullPath: string = '';
  @Trace init: boolean = false;

  async initFrom(fullPath: string) {
    const t0 = Date.now();
    const arrayBuffer = await readArrayBufferConcurrent(fullPath);
    if (arrayBuffer) {
      if (arrayBuffer.byteLength > 0) {
        try {
          const buffer = fastbuffer.from(arrayBuffer);
          const text = buffer.toString();
          // console.log(`[meowHistory][initFrom] Text: ${text}`);
          const readData = text.split('\n');

          console.log(`[meowHistory][initFrom] Initialized from ${fullPath}: ${readData.slice(0, 10)}...`);
          const extraData = this.data; // History entries produced by searches submitted before history is loaded.
          this.data = readData;

          // Put these back to history data.
          for (let idxHis = 0; idxHis < extraData.length; idxHis++) {
            this.addHistory(extraData[idxHis]);
            console.log(`    [meowHistory][initFrom] added extra history entry ${extraData[idxHis]}`);
          }
          if (extraData.length > 0) {
            saveHybrid(fullPath, this.data.join('\n'), true);
          }

        } catch (e) {
          console.error(`[meowHistory][initFrom] Failed: ${e}`);
        }
      } else {
        console.warn(`[meowHistory][initFrom] History file @ ${fullPath} is empty!`);
      }

    } else {
      // First use
      await saveHybrid(fullPath, '');
      console.warn(`[meowHistory][initFrom] Created blank history file @ ${fullPath}`);
    }
    this.init = true;
    this.fullPath = fullPath;
    console.log(`[meowHistory][initFrom] initialized! (${Date.now() - t0} ms)`);
  }

  async addHistory(key: string): Promise<boolean | undefined> {
    // maintain uniqueness
    const tryPos = this.data.indexOf(key);
    if (tryPos >= 0) {
      this.data.splice(tryPos, 1);
    }
    this.data.unshift(key);

    if (this.data.length > this.limit) {
      this.data.pop();
    }

    if (!this.init) {
      return undefined;
    }

    return saveHybrid(this.fullPath, this.data.join('\n'), true);
  }

  async deleteHistory(idx: number): Promise<boolean | undefined> {
    if (idx >= this.data.length) {
      console.warn(`[meowHistory][deleteHistory(${idx})] Failed! Index out of bound!`);
      return undefined;
    }
    this.data.splice(idx, 1);
    return saveHybrid(this.fullPath, this.data.join('\n'), true);
  }
}