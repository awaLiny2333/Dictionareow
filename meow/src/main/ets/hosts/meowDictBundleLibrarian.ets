import { meowDictBundle, positionType } from './meowDictBundle';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { retrieveDownloadDirectory, uri_2_path } from '../utils/storage';

@ObservedV2
export class meowDictBundleLibrarian {
  sandboxBasePath = 'bundles/';
  @Trace bundles: meowDictBundle[] = [];
  @Trace init: boolean = false;

  /**
   * Scans the bundles.
   * */
  async initAll(context: Context) {
    // Base path in sandbox
    await fileIo.listFile(context.filesDir + '/' + this.sandboxBasePath)
      .then((listResult) => {
        for (let index = 0; index < listResult.length; index++) {
          console.log(`[meowDictBundleLibrarian][initAll][base] Found bundle [${listResult[index]}]`);
          let bundle = new meowDictBundle();
          bundle.initFrom(`${context.filesDir + '/' + this.sandboxBasePath}${listResult[index]}/`, context, positionType.SANDBOX);
          this.bundles.push(bundle);
        }
        this.init = true;
        console.log(`[meowDictBundleLibrarian][initAll][base] OK. Total bundles.length = ${this.bundles.length}`);
      })
      .catch((e: BusinessError) => {
        console.error(`[meowDictBundleLibrarian][initAll][base] Failed! ${e}`);
      })

    await retrieveDownloadDirectory(context)
      .then((uri: string | undefined) => {
        if (uri) {
          console.log(`[meowDictBundleLibrarian][initAll][dl] DocumentViewPicker.save successfully, uris[0]: ${uri}`);
          let downloadPath = uri_2_path(uri);
          if (!downloadPath.endsWith('/')) {
            downloadPath = downloadPath + '/';
          }
          fileIo.listFile(downloadPath)
            .then((listResult) => {
              for (let index = 0; index < listResult.length; index++) {
                console.log(`[meowDictBundleLibrarian][initAll][dl] Found bundle [${listResult[index]}]`);
                let bundle = new meowDictBundle();
                bundle.initFrom(`${downloadPath}${listResult[index]}/`, context, positionType.DOWNLOAD);
                this.bundles.push(bundle);
              }
              this.init = true;
              console.log(`[meowDictBundleLibrarian][initAll][dl] OK. Total bundles.length = ${this.bundles.length}`);
            })
            .catch((e: BusinessError) => {
              console.error(`[meowDictBundleLibrarian][initAll][dl] Failed! ${e}`);
            })
        }
      })
  }

  createBundle(context: Context, rootDir: string, position: positionType) {
    const folderName = Date.now()
      .toString(16);
    if (!rootDir.endsWith('/')) {
      rootDir = rootDir + '/';
    }
    const baseDir = rootDir + folderName;
    console.log(`[meowDictBundleLibrarian][createBundle] baseDir: ${baseDir}`);
    try {
      fileIo.mkdirSync(baseDir);

      let bundle = new meowDictBundle();
      bundle.initFrom(baseDir + '/', context, position);
      this.bundles.push(bundle);

    } catch (e) {
      console.error(`[meowDictBundleLibrarian][createBundle] Failed: ${e}`);
    }
  }

  deleteBundle(index: number) {
    const sandboxBaseFolder = this.bundles[index].dirPathWithEndSlash;
    let dir = sandboxBaseFolder;
    // dir = dir.substring(0, dir.length - 1);
    this.bundles.splice(index, 1);
    fileIo.rmdir(dir)
      .catch((e: BusinessError) => {
        console.error(`[meowDictBundleLibrarian][deleteBundle][${dir}] Failed: ${e}`);
      });
  }

  // Helpers!

  constructSelectOptions() {
    let options: SelectOption[] = [];
    for (let index = 0; index < this.bundles.length; index++) {
      options.push({ value: this.bundles[index].mdx?.header?.Title || `${index}` });
    }
    return options;
  }
}