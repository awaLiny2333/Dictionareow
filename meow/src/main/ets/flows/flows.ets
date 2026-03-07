import { AppStorageV2, window } from '@kit.ArkUI';
import { meow, meowLevel } from '../utils/catsLogger';
import {
  getUpdateAvoid,
  getUpdateFreeWindowMode,
  listenAvoid,
  listenFocus,
  listenFreeWindowMode,
  meowLayoutModeStatus,
  meowPx2vp
} from '../utils/ui';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { meowDictBundleLibrarian } from '../hosts/meowDictBundleLibrarian';
import { readArrayBufferSync, retrieveDownloadDirectory, sandboxCreateDir, saveHybrid } from '../utils/storage';
import { buffer } from '@kit.ArkTS';
import { meowMisc } from '../hosts/meowMisc';
import { meowHistory } from '../hosts/meowHistory';
import Want from '@ohos.app.ability.Want';
import { systemShare } from '@kit.ShareKit';

// Flows
/**
 * Called in onWindowStageCreate, before windowStage.LoadContent
 * @param window window.Window
 * */
export async function aboutToLoadContent(windowStage: window.WindowStage, window: window.Window, context: Context) {
  initEnv(context);

  windowStage.setWindowRectAutoSave(true)
    .then(() => {
      meow('windowStage.setWindowRectAutoSave(true) Success!', 'init', meowLevel.INFO);
    })
    .catch((err: BusinessError) => {
      meow(`windowStage.setWindowRectAutoSave(true) Failed: ${JSON.stringify(err)}`, 'init', meowLevel.ERROR);
    });

  try {
    window.setImmersiveModeEnabledState(true);
  } catch (e) {
    meow(`window.setImmersiveModeEnabledState(true) Failed: ${JSON.stringify(e)}`, 'init', meowLevel.ERROR);
  }

  if (context) {
    meow(`[aboutToLoadContent] Context is True! Context is True!!`, 'flow', meowLevel.INFO);
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
    AppStorageV2.connect(meowLayoutModeStatus, () => new meowLayoutModeStatus(wideMode, width, height, window));
  } catch (e) {
    meow(`AppStorageV2.connect(meowLayoutModeStatus, () => new meowLayoutModeStatus(wideMode, width, height, window)); Failed: ${e}`, 'init', meowLevel.ERROR);
  }

  getUpdateAvoid(window);
  listenAvoid(window);

  getUpdateFreeWindowMode(context, window);
  listenFreeWindowMode(context, window);

  listenFocus(window);

  // initEnv(context);
}

// Actions

/**
 * Inits the environment. Creates the folders and tries to read files.
 * @param context The context.
 * */
export async function initEnv(context: Context) {
  await sandboxCreateDir('oops', context);
  const result = await saveHybrid(context.filesDir + '/oops/default.txt', '0', false);
  let defaultDictNumber = 0;
  
  if (result == undefined) {
    // Exist default file. Should read
    const read = readArrayBufferSync(context.filesDir + '/oops/default.txt');
    const readBuffer = buffer.from(read)
    const readString = readBuffer.toString();
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
    }
    refreshAllBundles(context);
  } catch (e) {
    console.error(`[flow][initEnv] Create new home bundles failed! ${e}`);
  }

  // Put this here to avoid stuck on main thread?
  setTimeout(() => {
    let myMeowHistory = AppStorageV2.connect<meowHistory>(meowHistory, 'meowHistory', () => new meowHistory())!;
    myMeowHistory.initFrom(`${context.filesDir}/oops/history.txt`);
  }, 100);
}

async function refreshAllBundles(context: Context) {
  console.log(`[flow][refreshAllBundles] BUILD!`);
  let librarian = AppStorageV2.connect<meowDictBundleLibrarian>(meowDictBundleLibrarian, 'meowDictBundleLibrarian', () => new meowDictBundleLibrarian())!;
  const downloadUri = await retrieveDownloadDirectory();
  librarian.downloadUri = downloadUri;
  setTimeout(() => {
    librarian.initAll(context);
  }, 10)
}

export function wantThis(w: Want) {
  console.log(`[wantThis] ${JSON.stringify(w)}`);
  let misc = AppStorageV2.connect<meowMisc>(meowMisc, 'meowMisc', () => new meowMisc())!;
  misc.wantDictIdx = -1;

  if (w.uri) {
    const wSplit = w.uri.split('/');
    const key = wSplit[wSplit.length - 1];
    misc.wantKey = key;
  } else {
    systemShare.getSharedData(w)
      .then((data) => {
        if (data) {
          const firstData = data.getRecords()[0].content;
          console.log(`[wantThis] Got first data: ${firstData}`);
          if (firstData) {
            misc.wantKey = firstData;
          }
        }
      })
      .catch((e: BusinessError) => {
        console.error(`[wantThis] systemShare.getSharedData(w) Failed: ${e}`);
      })
  }
}