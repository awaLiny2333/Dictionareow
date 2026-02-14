import { AppStorageV2, window } from '@kit.ArkUI';
import { meow, meowLevel } from '../utils/catsLogger';
import { getUpdateAvoid, getUpdateFreeWindowMode, listenAvoid, listenFocus, listenFreeWindowMode, meowLayoutModeStatus, meowPx2vp } from '../utils/ui';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { meowDictBundleLibrarian } from '../hosts/meowDictBundleLibrarian';
import { readArrayBufferSync, sandboxCreateDir, saveHybrid } from '../utils/storage';
import { buffer } from '@kit.ArkTS';
import { meowMisc } from '../hosts/meowMisc';
import { meowHistory } from '../hosts/meowHistory';

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
    const wideMode = width > 900;
    AppStorageV2.connect(meowLayoutModeStatus, () => new meowLayoutModeStatus(wideMode, width, height));
  } catch (e) {
    meow(`AppStorageV2.connect(meowLayoutModeStatus, () => new meowLayoutModeStatus(wideMode)); Failed: ${e}`, 'init', meowLevel.ERROR);
  }

  getUpdateAvoid(window);
  listenAvoid(window);

  getUpdateFreeWindowMode(context, window);
  listenFreeWindowMode(context, window);

  listenFocus(window);
}

// Actions

/**
 * Inits the environment. Creates the folders and tries to read files.
 * @param context The context.
 * */
export function initEnv(context: Context) {
  sandboxCreateDir('oops', context).then(() => {
    saveHybrid(context.filesDir + '/oops/default.txt', '0', false).then((result) => {
      let defaultDictNumber = 0;
      if (result == undefined) {
        // Should read
        const read = readArrayBufferSync(context.filesDir + '/oops/default.txt');
        const readString = buffer.from(read).toString();
        defaultDictNumber = Number(readString);
        console.log(`[initEnv] Read default dictionary is ${defaultDictNumber}!`);
        let misc = AppStorageV2.connect<meowMisc>(meowMisc, 'meowMisc', () => new meowMisc())!;
        misc.defaultDictBundleIndex = defaultDictNumber;
      }

      // New home
      try {
        let homeExist = fileIo.accessSync(context.filesDir + '/bundles');
        if (!homeExist) {
          fileIo.mkdirSync(context.filesDir + '/bundles');
          console.log(`[flow][initEnv] Created new home bundles!`);
        } else {
          refreshAllBundles(context, defaultDictNumber);
        }
      } catch (e) {
        console.error(`[flow][initEnv] Create new home bundles failed! ${e}`);
      }
    })

    let myMeowHistory = AppStorageV2.connect<meowHistory>(meowHistory, 'meowHistory', () => new meowHistory())!;
    myMeowHistory.initFrom(`${context.filesDir}/oops/history.txt`);
  })
}

function refreshAllBundles(context: Context, defaultId: number) {
  console.log(`[flow][refreshAllBundles] BUILD!`);
  let librarian = AppStorageV2.connect<meowDictBundleLibrarian>(meowDictBundleLibrarian, 'meowDictBundleLibrarian', () => new meowDictBundleLibrarian())!;
  librarian.initAll(context, defaultId);
}