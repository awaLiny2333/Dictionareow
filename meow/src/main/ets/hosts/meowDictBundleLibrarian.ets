import { meowDictBundle } from './meowDictBundle';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

@ObservedV2
export class meowDictBundleLibrarian {
  basePath = 'bundles/';
  @Trace bundles: meowDictBundle[] = [];

  /**
   * Scans the bundles.
   * */
  initAll(context: Context) {
    fileIo.listFile(context.filesDir + '/' + this.basePath)
      .then((listResult) => {
        for (let index = 0; index < listResult.length; index++) {
          console.log(`[meowDictBundleLibrarian][initAll] Found bundle [${listResult[index]}]`);
          let bundle = new meowDictBundle();
          bundle.initFrom(this.basePath + listResult[index] + '/', context);
          this.bundles.push(bundle);
        }
        console.log(`[meowDictBundleLibrarian][initAll] OK. Total bundles.length = ${this.bundles.length}`);
      })
      .catch((e: BusinessError) => {
        console.error(`[meowDictBundleLibrarian][initAll] Failed! ${e}`);
      })
  }

  createBundle(context: Context) {
    const sandboxDir = this.basePath + Date.now().toString(16);
    const baseDir = context.filesDir + '/' + sandboxDir;
    console.log(`[meowDictBundleLibrarian][createBundle] baseDir: ${baseDir}`);
    try {
      fileIo.mkdirSync(baseDir);
      fileIo.mkdirSync(baseDir + '/woof');
      fileIo.mkdirSync(baseDir + '/meow');
      fileIo.mkdirSync(baseDir + '/honk');

      let bundle = new meowDictBundle();
      bundle.initFrom(sandboxDir + '/', context);
      this.bundles.push(bundle);

    } catch (e) {
      console.error(`[meowDictBundleLibrarian][createBundle] Failed: ${e}`);
    }
  }

  deleteBundle(index: number, context: Context) {
    const sandboxBaseFolder = this.bundles[index].sandboxPathWithEndSlash;
    let dir = context.filesDir + '/' + sandboxBaseFolder;
    // dir = dir.substring(0, dir.length - 1);
    this.bundles.splice(index, 1);
    fileIo.rmdir(dir).catch((e: BusinessError) => {
      console.error(`[meowDictBundleLibrarian][deleteBundle][${dir}] Failed: ${e}`);
    });
  }

  constructSelectOptions() {
    let options: SelectOption[] = [];
    for (let index = 0; index < this.bundles.length; index++) {
      options.push({ value: this.bundles[index].mdx?.header?.Title || `${index}` });
    }
    return options;
  }
}