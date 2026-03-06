import { addUnitsToSize, resource2String } from '../utils/data';
import { fileCopy, listRecursivelyAllFilesUnderDir, saveHybrid } from '../utils/storage';
import { meowDict, meowDictType } from './meowDict';
import { fileIo } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';
import { toastDuration } from '../utils/ui';

export enum positionType {
  SANDBOX,
  DOWNLOAD,
  FOLDER
}

@ObservedV2
export class meowDictBundle {
  @Trace mdx: meowDict | undefined;
  @Trace mdds: meowDict[] = [];
  @Trace files: string[] = []; // Paths of files other than .mdd and .mdx
  @Trace fileSizes: number[] = [];
  @Trace totalSize: number = -1;
  position: positionType = positionType.SANDBOX;
  dirPathWithEndSlash: string | undefined;
  cacheKeys: string[] = []
  cacheBufs: ArrayBuffer[] = []

  /**
   * Inits the bundle from given path.
   * @param dirPath The path. For example: `${context.filesDir}/bundles/catExample/`.
   * @param context The Context.
   * @param type The position type.
   * */
  async initFrom(dirPath: string, context: Context, type: positionType) {
    this.position = type;

    if (!dirPath.endsWith('/')) {
      dirPath = dirPath + '/';
    }
    this.dirPathWithEndSlash = dirPath;
    this.files = []; // Reset. Even though not necessary.

    // Smart read
    let allFilesPlain: string[] = await listRecursivelyAllFilesUnderDir(dirPath);

    for (let fIdx = 0; fIdx < allFilesPlain.length; fIdx++) {
      const thisPath = allFilesPlain[fIdx];
      const thisPathLower = thisPath.toLowerCase();

      if (thisPathLower.endsWith('.mdx')) {
        // Is MDX
        if (!this.mdx) {
          let mdx = this.readMDict(thisPath, meowDictType.MDX, context);
          this.mdx = mdx;
          console.log(`[MeowDictBundle][initFrom][MDX][${thisPath}] ${this.mdx?.header?.Title}`);
        } else {
          console.log(`[MeowDictBundle][initFrom][MDX][${thisPath}] Rejected!`);
        }
      } else if (thisPathLower.endsWith('.mdd')) {
        // Is MDD
        let mdd = this.readMDict(thisPath, meowDictType.MDD, context);
        if (mdd) {
          this.mdds.push(mdd);
          console.log(`[MeowDictBundle][initFrom][MDD][${thisPath}] ${mdd.header?.Title}`);
        } else {
          console.log(`[MeowDictBundle][initFrom][MDD][${thisPath}] Failed or rejectd.`);
        }
      } else {
        // Is File
        try {
          this.files.push(thisPath);
          const stat = fileIo.statSync(thisPath);
          this.fileSizes.push(stat.size);
          console.log(`[MeowDictBundle][initFrom][File][${thisPath}]`);
        } catch (e) {
          console.error(`[MeowDictBundle][initFrom][File][${thisPath}] const stat = fileIo.statSync(thisPath) Failed! ${e}`);
        }
      }
    }

    this.updateSizes();
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
        const keyExt = keySplit[keySplit.length - 1];
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
        console.log(`[meowDictBundle][lookUpResourceFromMDDs] Found ${cachedTag}[${key}] in MDD [${this.mdds[index].fullPath}]! (${addUnitsToSize(meow[0].byteLength)}) (${Date.now() -
          startTime} ms)`);
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
    return this.lookUpResourceFromMDDs(key)
      .then((resultBuffer) => {
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
   * Updates the extra files additionally added (Other than .mdx & .mdd)
   * @param context Context.
   * */
  async refreshExtraFiles(context: Context, allFilesPlain?: string[]) {
    if (!this.dirPathWithEndSlash) {
      return;
    }
    
    // Files
    const files = allFilesPlain || (await listRecursivelyAllFilesUnderDir(this.dirPathWithEndSlash));
    this.files = [];

    for (let index = 0; index < files.length; index++) {
      const thisPath = files[index];
      const thisPathLower = thisPath.toLowerCase();
      if (thisPathLower.endsWith('.mdx') || thisPathLower.endsWith('.mdd')) {
        continue; // Skip mdd and mdx files
      }

      try {
        console.log(`[MeowDictBundle][refreshExtraFiles][${this.dirPathWithEndSlash}] [${thisPath}]!`);
        const stat = fileIo.statSync(thisPath);
        this.files.push(thisPath);
        this.fileSizes.push(stat.size);
      } catch (e) {
        console.error(`[MeowDictBundle][refreshExtraFiles][${this.dirPathWithEndSlash}] [${thisPath}] const stat = fileIo.statSync(thisPath) Failed! ${e}`);
      }

      if (index == this.files.length - 1) {
        // If is last
        this.updateSizes();
      }
    }
  }

  /**
   * Calculates and updates the totalSize of this bundle.
   * Included in refreshExtraFiles.
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
   * Auto adds files to the bundle. Will use the first .mdx file for MDX field, add all .mdd files as MDD and all other types as normal files.
   * @param sourcePaths The source paths of dict files.
   * @param UIContext The UIContext.
   */
  async autoAdd(sourcePaths: string[], UIContext: UIContext) {
    const total = sourcePaths.length;
    for (let idx = 0; idx < sourcePaths.length; idx++) {
      const thisPath = sourcePaths[idx];
      const thisPathLower = thisPath.toLowerCase();
      if (thisPathLower.endsWith('.mdx')) {
        if (this.mdx) {
          console.log(`[autoAdd] ${thisPath} MDX exist! Skipping this mdx... Sorry :O`);
        } else {
          await this.addMDX(thisPath, UIContext, idx + 1, total);
        }
      } else if (thisPathLower.endsWith('.mdd')) {
        await this.addMDD(thisPath, UIContext, idx + 1, total);
      } else {
        await this.addFile(thisPath, UIContext, idx + 1, total);
      }
    }
    await this.refreshExtraFiles(UIContext.getHostContext()!);
  }

  /**
   * Adds an MDX to the bundle.
   * @param sourcePath The source path of file.
   * @param context The UIContext.
   * */
  async addMDX(sourcePath: string, UIContext: UIContext, thisIdx: number, total: number) {
    const sourcePathSplit = sourcePath.split('/');
    const fileName: string | undefined = sourcePathSplit[sourcePathSplit.length - 1];
    const destPath: string = this.dirPathWithEndSlash + fileName;
    this.toast(UIContext, `${resource2String($r('app.string.add_importing'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
    if (this.mdx) {
      try {
        fileIo.unlinkSync(this.mdx.fullPath);
      } catch (e) {
        console.error(`[MeowDictBundle][addMDX][${sourcePath}][${destPath}] (${thisIdx}/${total}) Unlink this.mdx?.fullPath = ${this.mdx?.fullPath} Failed! ${e}`);
      }
    }
    this.mdx = undefined;
    await fileCopy(sourcePath, destPath, true)
      .then((result) => {
        if (result == true) {
          this.mdx = new meowDict(meowDictType.MDX, destPath);
          this.mdx.init();
          console.log(`[MeowDictBundle][addMDX][${sourcePath}][${destPath}] (${thisIdx}/${total})`);
          this.updateSizes();
        }
        if (result == false) {
          this.toast(UIContext, `${resource2String($r('app.string.add_fail_general'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
        } else {
          this.toast(UIContext, `${resource2String($r('app.string.add_success'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
        }
      })
  }

  /**
   * Adds an MDD to the bundle.
   * @param sourcePath The source path of file.
   * @param context The UIContext.
   * */
  async addMDD(sourcePath: string, UIContext: UIContext, thisIdx: number, total: number) {
    // Save (copy) file
    const targetPathSplit = sourcePath.split('/');
    const fileName: string | undefined = targetPathSplit[targetPathSplit.length - 1];
    const destPath = this.dirPathWithEndSlash + fileName;
    this.toast(UIContext, `${resource2String($r('app.string.add_importing'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
    await fileCopy(sourcePath, destPath, false)
      .then((result) => {
        if (result == true) {
          // Create object
          let mdd = new meowDict(meowDictType.MDD, destPath);
          this.mdds.push(mdd);
          mdd.init();
          console.log(`[MeowDictBundle][addMDD][${sourcePath}][${destPath}][${fileName}] (${thisIdx}/${total})`);
          this.updateSizes();
        }
        if (result == undefined) {
          this.toast(UIContext, `${resource2String($r('app.string.add_fail_same_name'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
        } else if (result == false) {
          this.toast(UIContext, `${resource2String($r('app.string.add_fail_general'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
        } else {
          this.toast(UIContext, `${resource2String($r('app.string.add_success'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
        }
      })
  }

  /**
   * Adds a file to the bundle.
   * @param sourcePath The source path of file.
   * @param context The UIContext.
   * @param updateFile Will trigger updateFilesSync if set true. usually use on the last add action of a batch import.
   * */
  async addFile(sourcePath: string, UIContext: UIContext, thisIdx: number, total: number) {
    const sourcePathSplit = sourcePath.split('/');
    const fileName: string | undefined = sourcePathSplit[sourcePathSplit.length - 1];

    const destPathPure = this.dirPathWithEndSlash;
    const pathWithMeow = this.dirPathWithEndSlash + 'meow/';
    let destPath = pathWithMeow + fileName;
    try {
      if (!fileIo.accessSync(pathWithMeow)) {
        destPath = destPathPure + fileName;
      }
    } catch (e) {
      // Leave this along first.
    }

    this.toast(UIContext, `${resource2String($r('app.string.add_importing'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
    console.log(`[meowDictBundle][addFile][${sourcePath}][${fileName}] (${thisIdx}/${total})`);
    await fileCopy(sourcePath, destPath, false)
      .then((result) => {
        if (result == undefined) {
          this.toast(UIContext, `${resource2String($r('app.string.add_fail_same_name'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
        } else if (result == false) {
          this.toast(UIContext, `${resource2String($r('app.string.add_fail_general'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
        } else {
          this.toast(UIContext, `${resource2String($r('app.string.add_success'), UIContext.getHostContext()!)} ${fileName} (${thisIdx}/${total})`);
        }
      })
  }

  /**
   * Reads an MDict file and store the meowDict file into appStorage of given key
   * @param fullPath The path. With slash in front. e.g. '/woof/woof.mdx'
   * @param type meowDictType
   * @param appStorageKey The key of appStorage record
   * @param context Context
   * @returns Nothing
   * */
  private readMDict(fullPath: string, type: meowDictType = meowDictType.MDX, context: Context) {
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
      UIContext.getPromptAction()
        .showToast({
          message: msg,
          duration: toastDuration
        });
    } catch (e) {
      console.log(`[MeowDictBundle] showToast failed: ${e}`);
    }
  }
}
