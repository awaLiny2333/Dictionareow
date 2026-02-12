import { addUnitsToSize } from '../utils/data';
import { fileCopy, saveHybrid } from '../utils/storage';
import { meowDict, meowDictType } from './meowDict';
import { fileIo } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';
import { toastDuration } from '../utils/ui';

@ObservedV2
export class meowDictBundle {
  @Trace mdx: meowDict | undefined;
  @Trace mdds: meowDict[] = [];
  @Trace files: string[] = [];
  @Trace fileSizes: number[] = [];
  @Trace totalSize: number = -1;
  sandboxPathWithEndSlash: string | undefined;
  cacheKeys: string[] = []
  cacheBufs: ArrayBuffer[] = []

  /**
   * Inits the bundle from given path.
   * @param sandboxPathWithEndSlash The path, ending with '/'. For example: 'bundles/catExample/'.
   * This directory should guarantee that .../woof, .../honk and .../meow exist.
   * @param context The Context.
   * */
  async initFrom(sandboxPathWithEndSlash: string, context: Context) {
    this.sandboxPathWithEndSlash = sandboxPathWithEndSlash;
    // MDX
    fileIo.listFile(context.filesDir + '/' + sandboxPathWithEndSlash + 'woof/')
      .then((r) => {
        if (r.length > 0) {
          let mdx = this.readMDict('/' + sandboxPathWithEndSlash + 'woof/' + r[0], meowDictType.MDX, context);
          this.mdx = mdx;
          console.log(`[readMDict] ${this.mdx?.header?.Title}`);
          this.updateSizes();
        } else {
          console.warn(`[readMDict][${sandboxPathWithEndSlash}] NO MDX?`);
        }
      })
      .catch((e: BusinessError) => {
        console.error(`[meowDictBundle][initFrom] fileIo.listFile(context.filesDir + '/honk/') Failed: ${e}`);
      })
    // MDD
    fileIo.listFile(context.filesDir + '/' + sandboxPathWithEndSlash + 'honk/')
      .then((r) => {
        for (let index = 0; index < r.length; index++) {
          let mdd = this.readMDict('/' + sandboxPathWithEndSlash + 'honk/' + r[index], meowDictType.MDD, context);
          if (mdd) {
            this.mdds.push(mdd);
          }
        }
        this.updateSizes();
      })
      .catch((e: BusinessError) => {
        console.error(`[meowDictBundle][initFrom] fileIo.listFile(context.filesDir + '/honk/') Failed: ${e}`);
      })
    // Files
    this.updateFilesSync(context);
  }

  // Use

  /**
   * Checks if the bundle MDX contains a key.
   * @param key The key.
   * @returns true or false.
   * */
  async hasKeyInMDX(key: string) {
    return this.mdx?.hasKey(key, false)?.then((r) => {
      return r;
    }) || false;
  }

  /**
   * Gets content of a key.
   * @param key The key.
   * @returns Arraybuffer of content or undefined if key not found.
   * */
  lookUpKeyFromMDX(key: string): Promise<ArrayBuffer[] | undefined> | undefined {
    return this.mdx?.lookUpKey(key, false);
  }

  /**
   * Gets resource data of a key.
   * @param key The key.
   * @returns Arraybuffer of content or undefined if key not found.
   * */
  async lookUpResourceFromMDDs(key: string) {
    const startTime: number = Date.now();

    const cacheIdx = this.cacheKeys.indexOf(key);
    if (cacheIdx >= 0) {
      console.log(`[meowDictBundle][lookUpResourceFromMDDs] Fetched [${key}] from cache (${Date.now() - startTime} ms)`);
      return this.cacheBufs[cacheIdx];
    }

    for (let index = 0; index < this.mdds.length; index++) {
      let meow = await this.mdds[index].lookUpKey(key, true);
      if (meow) {
        let cachedTag = '';
        const keySplit = key.split('.');
        const keyExt = keySplit[keySplit.length-1];
        const isJsTtfCss = ['js', 'ttf', 'css', 'woff'].includes(keyExt.toLowerCase());
        if (meow[0].byteLength > 100000 || isJsTtfCss) {
          this.cacheKeys.push(key);
          this.cacheBufs.push(meow[0]);
          if (isJsTtfCss) {
            cachedTag = `and cached (isJsTtfCss)! `;
          } else {
            cachedTag = `and cached! `;
          }
        }
        console.log(`[meowDictBundle][lookUpResourceFromMDDs] Found ${cachedTag}[${key}] in MDD [${this.mdds[index].fullPath}]! (${addUnitsToSize(meow[0].byteLength)}) (${Date.now() - startTime} ms)`);
        return meow[0];
      }
    }
    console.error(`[meowDictBundle][lookUpResourceFromMDDs] [${key}] Not found in any MDD!`);
    return undefined;
  }

  /**
   * Extracts a resource file from an MDD and saves it to a temp path.
   * @param key The key.
   * @param context The Context.
   * @returns String of extracted file path or undefined if key not found.
   * */
  async extractFileToTemp(key: string, context: Context) {
    return this.lookUpResourceFromMDDs(key).then((resultBuffer) => {
      if (!resultBuffer) {
        return undefined;
      }

      console.log(`[MeowDictBundle][extractFile] Got result!`);

      let fileName = key;
      if (fileName.substring(0, 1) == '\\') {
        fileName = fileName.substring(1);
      }

      const path = context.tempDir + '/' + fileName;
      saveHybrid(path, resultBuffer);

      return path;
    })
  }

  // Status maintenance

  /**
   * Updates the extra files additionally added.
   * @param context Context.
   * */
  updateFilesSync(context: Context) {
    // Files
    console.log(`[MeowDictBundle][updateFiles][${context.filesDir + '/' + this.sandboxPathWithEndSlash}]:`);
    this.files = [];
    try {
      const r = fileIo.listFileSync(context.filesDir + '/' + this.sandboxPathWithEndSlash + 'meow/');
      for (let index = 0; index < r.length; index++) {
        const path = context.filesDir + '/' + this.sandboxPathWithEndSlash + 'meow/' + r[index];
        this.files.push(path);
        console.log(`    [MeowDictBundle][updateFiles][${context.filesDir + '/' + this.sandboxPathWithEndSlash}] [${path}]!`);
        const stat = fileIo.statSync(path)
        this.fileSizes.push(stat.size);
        if (index == r.length - 1) {
          this.updateSizes();
        }
      }
    } catch (e) {
      console.error(`[MeowDictBundle][updateFiles] Failed: ${e}`);
    }
  }

  /**
   * Calculates and updates the totalSize of this bundle.
   * */
  updateSizes() {
    console.log(`[MeowDictBundle][updateSizes]!`);
    let totalSize = 0;
    for (let index = 0; index < this.mdds.length; index++) {
      totalSize += this.mdds[index].size;
    }
    for (let index = 0; index < this.fileSizes.length; index++) {
      totalSize += this.fileSizes[index];
    }
    if (this.mdx) {
      totalSize += this.mdx.size;
    }
    this.totalSize = totalSize;
  }

  // File operations

  /**
   * Adds an MDX to the bundle.
   * @param sourcePath The source path of file.
   * @param context The UIContext.
   * */
  addMDX(sourcePath: string, UIContext: UIContext) {
    const sourcePathSplit = sourcePath.split('/');
    const fileName: string | undefined = sourcePathSplit[sourcePathSplit.length-1];
    const destPath: string = UIContext.getHostContext()!.filesDir + '/' + this.sandboxPathWithEndSlash + 'woof/' + fileName;
    this.toast(UIContext, $r('app.string.add_importing'));
    if (this.mdx) {
      try {
        fileIo.unlinkSync(this.mdx.fullPath);
      } catch (e) {
        console.error(`[MeowDictBundle][addMDX][${sourcePath}][${destPath}] Unlink this.mdx?.fullPath = ${this.mdx?.fullPath} Failed! ${e}`);
      }
    }
    this.mdx = undefined;
    fileCopy(sourcePath, destPath, true).then((result) => {
      if (result == true) {
        this.mdx = new meowDict(meowDictType.MDX, destPath);
        this.mdx.init();
        console.log(`[MeowDictBundle][addMDX][${sourcePath}][${destPath}]`);
        this.updateSizes();
      }
      if (result == false) {
        this.toast(UIContext, $r('app.string.add_fail_general'));
      } else {
        this.toast(UIContext, $r('app.string.add_success'));
      }
    })
    // sandboxSaveHybrid('woof/woof.mdx', r.buf!, this.context, true);
  }

  /**
   * Adds an MDD to the bundle.
   * @param sourcePath The source path of file.
   * @param context The UIContext.
   * */
  addMDD(sourcePath: string, UIContext: UIContext) {
    // Save (copy) file
    const targetPathSplit = sourcePath.split('/');
    const fileName: string | undefined = targetPathSplit[targetPathSplit.length-1];
    const destPath = UIContext.getHostContext()!.filesDir + '/' + this.sandboxPathWithEndSlash + 'honk/' + fileName;
    this.toast(UIContext, $r('app.string.add_importing'));
    fileCopy(sourcePath, destPath, false).then((result) => {
      if (result == true) {
        // Create object
        let mdd = new meowDict(meowDictType.MDD, destPath);
        this.mdds.push(mdd);
        mdd.init();
        console.log(`[MeowDictBundle][addMDD][${sourcePath}][${destPath}][${fileName}]`);
        this.updateSizes();
      }
      if (result == undefined) {
        this.toast(UIContext, $r('app.string.add_fail_same_name'));
      } else if (result == false) {
        this.toast(UIContext, $r('app.string.add_fail_general'));
      } else {
        this.toast(UIContext, $r('app.string.add_success'));
      }
    })
  }

  /**
   * Adds a file to the bundle.
   * @param sourcePath The source path of file.
   * @param context The UIContext.
   * @param updateFile Will trigger updateFilesSync if set true. usually use on the last add action of a batch import.
   * */
  addFile(sourcePath: string, UIContext: UIContext, updateFile: boolean = true) {
    const sourcePathSplit = sourcePath.split('/');
    const fileName: string | undefined = sourcePathSplit[sourcePathSplit.length-1];
    const destPath = UIContext.getHostContext()!.filesDir + '/' + this.sandboxPathWithEndSlash + 'meow/' + fileName;
    this.toast(UIContext, $r('app.string.add_importing'));
    fileCopy(sourcePath, destPath, true).then((result) => {
      if (updateFile) {
        this.updateFilesSync(UIContext.getHostContext()!);
      }
      if (result == undefined) {
        this.toast(UIContext, $r('app.string.add_fail_same_name'));
      } else if (result == false) {
        this.toast(UIContext, $r('app.string.add_fail_general'));
      } else {
        this.toast(UIContext, $r('app.string.add_success'));
      }
    })
    // sandboxSaveHybrid('meow/' + r.fileName!, r.buf!, this.context, true);
    console.log(`[meowDictBundle][addFile][${sourcePath}][${fileName}]`);
  }

  /**
   * Reads an MDict file and store the meowDict file into appStorage of given key
   * @param sandboxPath The sandbox path. With context.filesDir as base. With slash in front.
   * @param type meowDictType
   * @param appStorageKey The key of appStorage record
   * @param context Context
   * @returns Nothing
   * */
  private readMDict(sandboxPath: string = '/woof/woof.mdx', type: meowDictType = meowDictType.MDX, context: Context) {
    const fullPath = context.filesDir + sandboxPath;
    try {
      const existMdd = fileIo.accessSync(fullPath);
      if (existMdd) {
        console.log(`[Meow][readMDict][${fullPath}] Exist!`);
        let a = new meowDict(type, fullPath);
        a.init();
        return a;
      } else {
        console.error(`[Meow][readMDict][${fullPath}] Not exist!`);
      }
    } catch (e) {
      console.error(`[Meow][readMDict][${fullPath}] Check and load existing mdx failed: ${e}`);
    }
    return undefined;
  }

  private toast(UIContext: UIContext, msg: ResourceStr) {
    try {
      UIContext.getPromptAction().showToast({
        message: msg,
        duration: toastDuration
      });
    } catch (e) {
      console.log(`[MeowDictBundle] showToast failed: ${e}`);
    }
  }
}
