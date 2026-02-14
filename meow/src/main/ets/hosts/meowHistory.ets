import { readArrayBufferConcurrent, saveHybrid } from '../utils/storage';
import { fastbuffer } from '@kit.ArkTS';

@ObservedV2
export class meowHistory {
  limit: number = 233;
  @Trace data: string[] = [];
  fullPath: string = '';
  @Trace init: boolean = false;

  async initFrom(fullPath: string) {
    const arrayBuffer = await readArrayBufferConcurrent(fullPath);
    if (arrayBuffer) {
      try {
        const text = fastbuffer.from(arrayBuffer).toString();
        console.log(`[meowHistory][initFrom] Text: ${text}`);
        const readData = text.split('\n');
        const needSave = this.data.length > 0;

        console.log(`[meowHistory][initFrom] Initialized from ${fullPath}: ${readData}`);
        this.data = this.data.concat(readData);

        if (needSave) {
          saveHybrid(fullPath, '', true);
        }

      } catch (e) {
        console.error(`[meowHistory][initFrom] Failed: ${e}`);
      }

      this.init = true;
    } else {
      // First use
      await saveHybrid(fullPath, '');
      console.warn(`[meowHistory][initFrom] Created blank history file @ ${fullPath}`);
    }
    this.fullPath = fullPath;
  }

  addHistory(key: string) {
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
      return;
    }

    saveHybrid(this.fullPath, this.data.join('\n'), true);
  }
}