import { AppStorageV2, window } from '@kit.ArkUI';
import { meow, meowLevel } from '../utils/catsLogger';
import lazy { sandboxCreateDir } from '../utils/storage';
import { getUpdateAvoid, getUpdateFreeWindowMode, listenAvoid, listenFreeWindowMode, meowLayoutModeStatus, meowPx2vp } from '../utils/uiEnv';
import { fileIo } from '@kit.CoreFileKit';
import { meowDict, meowDictBundle, meowDictType } from '../hosts/meowDict';
import { BusinessError } from '@kit.BasicServicesKit';

// Flows

/**
 * Called in onWindowStageCreate, before windowStage.LoadContent
 * @param window window.Window
 * */
export async function aboutToLoadContent(windowStage: window.WindowStage, window: window.Window, context: Context) {
  initEnv(context);

  windowStage.setWindowRectAutoSave(true).then(() => {
    meow('windowStage.setWindowRectAutoSave(true) Success!', 'init', meowLevel.INFO);
  }).catch((err: BusinessError) => {
    meow(`windowStage.setWindowRectAutoSave(true) Failed: ${err}`, 'init', meowLevel.ERROR);
  });

  try {
    window.setImmersiveModeEnabledState(true);
  } catch (e) {
    meow(`window.setImmersiveModeEnabledState(true) Failed: ${e}`, 'init', meowLevel.ERROR);
  }
}

/**
 * Called immediately after windowStage.LoadContent
 * @param window window.Window
 * */
export function onLoadContent(window: window.Window, context: Context) {
  try {
    window.setWindowDecorVisible(false);
  } catch (e) {
    meow(`window.setWindowDecorVisible(false) Failed: ${e}`, 'init', meowLevel.ERROR);
  }

  try {
    const rect: window.Rect = window.getWindowProperties().windowRect;
    const width = meowPx2vp(rect.width);
    const height = meowPx2vp(rect.height);
    const wideMode = width > 800;
    AppStorageV2.connect(meowLayoutModeStatus, () => new meowLayoutModeStatus(wideMode, width, height));
  } catch (e) {
    meow(`AppStorageV2.connect(meowLayoutModeStatus, () => new meowLayoutModeStatus(wideMode)); Failed: ${e}`, 'init', meowLevel.ERROR);
  }

  getUpdateAvoid(window);
  listenAvoid(window);

  getUpdateFreeWindowMode(context, window);
  listenFreeWindowMode(context, window);
}

// Actions

/**
 * Inits the environment. Creates the folders and tries to read files.
 * @param context The context.
 * */
export function initEnv(context: Context) {
  return sandboxCreateDir('meow', context).then(() => {
    return sandboxCreateDir('woof', context).then(() => {
      return sandboxCreateDir('honk', context).then(() => {
        let bundle = AppStorageV2.connect<meowDictBundle>(meowDictBundle, 'meowDictExampleBundle', () => new meowDictBundle())!;
        // MDX
        let mdx = readMDict('/woof/woof.mdx', meowDictType.MDX, context);
        bundle.mdx = mdx;
        // MDD
        fileIo.listFile(context.filesDir + '/honk/')
          .then((r) => {
            for (let index = 0; index < r.length; index++) {
              const path = context.filesDir + '/honk/' + r[index];
              let mdd = new meowDict(meowDictType.MDD, path);
              bundle.mdds.push(mdd);
              mdd.init();
            }
          })
          .catch((e: BusinessError) => {
            console.error(`[Meow][initEnv] fileIo.listFile(context.filesDir + '/honk/') Failed: ${e}`);
          })
        // Files
        bundle.updateFiles(context);
        // readMDict('/woof/woof.mdd', meowDictType.MDD, 'meowDictExampleMDD', context);
      })
    })
  })
}

/**
 * Reads an MDict file and store the meowDict file into appStorage of given key
 * @param sandboxPath The sandbox path. With context.filesDir as base
 * @param type meowDictType
 * @param appStorageKey The key of appStorage record
 * @param context Context
 * @returns Nothing
 * */
function readMDict(sandboxPath: string = '/woof/woof.mdx', type: meowDictType = meowDictType.MDX, context: Context) {
  try {
    const existMdd = fileIo.accessSync(context.filesDir + sandboxPath);
    if (existMdd) {
      console.log(`[Meow][readMDict][${sandboxPath}] Exist!`);
      let a = new meowDict(type, context.filesDir + sandboxPath);
      a.init();
      return a;
    }
  } catch (e) {
    console.error(`[Meow][readMDict][${sandboxPath}] Check and load existing mdx failed: ${e}`);
  }
  return undefined;
}
