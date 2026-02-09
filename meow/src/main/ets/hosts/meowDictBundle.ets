import { addUnitsToSize } from '../utils/data';
import { fileCopy, sandboxCreateDir, saveHybrid } from '../utils/storage';
import { meowDict, meowDictType } from './meowDict';
import { fileIo } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';

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

  async initFrom(sandboxPathWithEndSlash: string, context: Context) {
    if (sandboxPathWithEndSlash != '') {
      try {
        fileIo.mkdirSync(context.filesDir + '/' + sandboxPathWithEndSlash);
      } catch (e) {
        console.error(`[meowDictBundle][initFrom] fileIo.mkdirSync(context.filesDir + '/' + baseFolderNameWithSlash); Failed: ${e}`);
      }
    }

    this.sandboxPathWithEndSlash = sandboxPathWithEndSlash;
    return sandboxCreateDir(sandboxPathWithEndSlash + 'meow', context).then(() => {
      return sandboxCreateDir(sandboxPathWithEndSlash + 'woof', context).then(() => {
        return sandboxCreateDir(sandboxPathWithEndSlash + 'honk', context).then(() => {
          // MDX
          fileIo.listFile(context.filesDir + '/' + sandboxPathWithEndSlash + 'woof/')
            .then((r) => {
              if (r.length > 0) {
                let mdx = readMDict('/' + sandboxPathWithEndSlash + 'woof/' + r[0], meowDictType.MDX, context);
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
                let mdd = readMDict('/' + sandboxPathWithEndSlash + 'honk/' + r[index], meowDictType.MDD, context);
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
          // readMDict('/woof/woof.mdd', meowDictType.MDD, 'meowDictExampleMDD', context);
        })
      })
    })
  }

  async lookUpResourceFromMDDs(key: string) {
    const startTime: number = Date.now();

    const cacheIdx = this.cacheKeys.indexOf(key);
    if (cacheIdx >= 0) {
      console.log(`[meowDictBundle][lookUpResourceFromMDDs] Fetch from cache [${key}]`);
      return this.cacheBufs[cacheIdx];
    }

    for (let index = 0; index < this.mdds.length; index++) {
      let meow = await this.mdds[index].lookUpKey(key);
      if (meow) {
        if (meow.byteLength > 100000) {
          this.cacheKeys.push(key);
          this.cacheBufs.push(meow);
          console.log(`[meowDictBundle][lookUpResourceFromMDDs] Cached [${key}] (${addUnitsToSize(meow.byteLength)})`);
        }
        console.log(`[meowDictBundle][lookUpResourceFromMDDs] Found [${key}] in MDD [${this.mdds[index].fullPath}]! (${Date.now() - startTime} ms)`);
        return meow;
      }
    }
    console.error(`[meowDictBundle][lookUpResourceFromMDDs] [${key}] Not found in any MDD!`);
    return undefined;
  }

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

  /**
   * Updates the extra files additionally added.
   * @param context Context.
   * */
  updateFilesSync(context: Context) {
    // Files
    console.log(`
[MeowDictBundle][updateFiles][${context.filesDir + '/' + this.sandboxPathWithEndSlash}]:`);
    this.files = [];
    const r = fileIo.listFileSync(context.filesDir + '/' + this.sandboxPathWithEndSlash + 'meow/')
    // .then((r) => {
    for (let index = 0; index < r.length; index++) {
      const path = context.filesDir + '/' + this.sandboxPathWithEndSlash + 'meow/' + r[index];
      this.files.push(path);
      console.log(`    [MeowDictBundle][updateFiles][${context.filesDir + '/' + this.sandboxPathWithEndSlash}] [${path}]!`);
      const stat = fileIo.statSync(path)
      // .then((stat) => {
      this.fileSizes.push(stat.size);
      if (index == r.length - 1) {
        this.updateSizes();
      }
      // }).catch((e: BusinessError) => {
      //   console.error(`[MeowDictBundle][updateFiles] fileIo.stat(path) Failed: ${e}`);
      // })
    }
    // })
    // .catch((e: BusinessError) => {
    //   console.error(`[MeowDictBundle][updateFiles] fileIo.listFile(context.filesDir + '/honk/') Failed: ${e}`);
    // })
  }

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

  addMDX(sourcePath: string, context: Context) {
    const sourcePathSplit = sourcePath.split('/');
    const fileName: string | undefined = sourcePathSplit[sourcePathSplit.length-1];
    const destPath: string = context.filesDir + '/' + this.sandboxPathWithEndSlash + 'woof/' + fileName;
    fileCopy(sourcePath, destPath).then(() => {
      this.mdx = new meowDict(meowDictType.MDX, destPath);
      this.mdx.init();
      console.log(`[MeowDictBundle][addMDX][${sourcePath}][${destPath}]`);
      this.updateSizes();
    })
    // sandboxSaveHybrid('woof/woof.mdx', r.buf!, this.context, true);
  }

  addMDD(sourcePath: string, context: Context) {
    // Save (copy) file
    const targetPathSplit = sourcePath.split('/');
    const fileName: string | undefined = targetPathSplit[targetPathSplit.length-1];
    const destPath = context.filesDir + '/' + this.sandboxPathWithEndSlash + 'honk/' + fileName;
    fileCopy(sourcePath, destPath).then(() => {
      // Create object
      let mdd = new meowDict(meowDictType.MDD, destPath);
      this.mdds.push(mdd);
      mdd.init();
      console.log(`[MeowDictBundle][addMDD][${sourcePath}][${destPath}][${fileName}]`);
      this.updateSizes();
    })
  }

  addFile(sourcePath: string, context: Context, updateFile: boolean = true) {
    const sourcePathSplit = sourcePath.split('/');
    const fileName: string | undefined = sourcePathSplit[sourcePathSplit.length-1];
    fileCopy(sourcePath, context.filesDir + '/' + this.sandboxPathWithEndSlash + 'meow/' + fileName).then(() => {
      if (updateFile) {
        this.updateFilesSync(context);
      }
    })
    // sandboxSaveHybrid('meow/' + r.fileName!, r.buf!, this.context, true);
    console.log(`[meowDictBundle][addFile][${sourcePath}][${fileName}]`);
  }
}

/**
 * Reads an MDict file and store the meowDict file into appStorage of given key
 * @param sandboxPath The sandbox path. With context.filesDir as base. With slash in front.
 * @param type meowDictType
 * @param appStorageKey The key of appStorage record
 * @param context Context
 * @returns Nothing
 * */
function readMDict(sandboxPath: string = '/woof/woof.mdx', type: meowDictType = meowDictType.MDX, context: Context) {
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