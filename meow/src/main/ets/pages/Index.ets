import { meowDict, meowDictType } from '../hosts/meowDict';
import { fileDocumentPick2ArrayBuffer, sandboxCreateDir, sandboxSaveSync } from '../utils/storage';
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { defaultDecorHeight, meowAvoid, meowFreeWindowModeStatus } from '../utils/uiEnv';
import { BusinessError } from '@kit.BasicServicesKit';
import { keepOnlyAlphanumericGlobal } from '../utils/data';

@Entry
@ComponentV2
struct Index {
  @Local myMeowAvoid: meowAvoid = AppStorageV2.connect<meowAvoid>(meowAvoid)!;
  @Local myMeowFreeWindowModeStatus: meowFreeWindowModeStatus = AppStorageV2.connect<meowFreeWindowModeStatus>(meowFreeWindowModeStatus)!;
  @Local windowWidth: number = 0;
  @Local windowHeight: number = 0;
  @Local wideMode: boolean = false;
  // Data
  @Local meowDictExampleMDX: meowDict = AppStorageV2.connect<meowDict>(meowDict, 'meowDictExampleMDX', () => new meowDict(meowDictType.MDX))!;
  @Local meowDictExampleMDD: meowDict = AppStorageV2.connect<meowDict>(meowDict, 'meowDictExampleMDD', () => new meowDict(meowDictType.MDD))!;
  // Runtime data
  @Local private render: boolean = false;
  @Local private lookUpWordMDX: string = '';
  @Local private keywordsInSameIndexBlock: string[] = [];
  @Local private keywordsInSameIndexBlockRelative: string[] = [];
  private webController: WebviewController = new webview.WebviewController();
  private refreshForResourcesTimeout: number | undefined;

  build() {
    Column() {
      if (this.render) {
        if (this.myMeowFreeWindowModeStatus.on) {
          Row() {
            Text(this.meowDictExampleMDX?.header?.Title)
          }
          .padding(10)
          .height(defaultDecorHeight)
        }

        Column({ space: 10 }) {
          RelativeContainer() {
            Row({ space: 10 }) {
              Button(this.meowDictExampleMDX?.rawData ? 'MDX  󰀓' : '󰀵 MDX')
                .onClick(() => {
                  fileDocumentPick2ArrayBuffer(['.mdx']).then((r) => {
                    if (r.succeed) {
                      this.meowDictExampleMDX = new meowDict(meowDictType.MDX, r.buf!);
                      this.loadWeb(this.meowDictExampleMDX.header?.toHtml());

                      sandboxCreateDir('meow', this.getUIContext().getHostContext()!, true).then(() => {
                        sandboxSaveSync('woof/woof.mdx', r.buf!, this.getUIContext().getHostContext()!, true);
                      })
                    }
                  })
                })
              Button(this.meowDictExampleMDD?.rawData ? 'MDD  󰀓' : '󰀵 MDD')
                .onClick(() => {
                  fileDocumentPick2ArrayBuffer(['.mdd']).then((r) => {
                    if (r.succeed) {
                      this.meowDictExampleMDD = new meowDict(meowDictType.MDD, r.buf!);
                      // this.loadWeb(this.meowDictExampleMDD.header?.toHtml());
                      sandboxSaveSync('woof/woof.mdd', r.buf!, this.getUIContext().getHostContext()!, true);
                    }
                  })
                })
              Button('󰀵 Extra')
                .onClick(() => {
                  fileDocumentPick2ArrayBuffer(['.css', '.js', '.jpg', '.jpeg', '.png', '.svg']).then((r) => {
                    if (r.succeed) {
                      sandboxSaveSync('meow/' + r.fileName!, r.buf!, this.getUIContext().getHostContext()!, true);
                    }
                  })
                })
              Row()
            } // Buttons
            .id('fileControlButtons')
            .alignRules({ left: { anchor: '__container__', align: HorizontalAlign.Start }, top: { anchor: '__container__', align: VerticalAlign.Top } })
            .animation({ curve: Curve.ExtremeDeceleration, duration: 200 })

            Row({ space: 10 }) {
              TextInput({ placeholder: '󰀩 MDX', text: this.lookUpWordMDX })
                .layoutWeight(1)
                .onChange((e) => {
                  this.lookUpWordMDX = e;
                })
                .onSubmit(() => {
                  clearTimeout(this.refreshForResourcesTimeout);
                  this.search(this.meowDictExampleMDX, this.lookUpWordMDX);
                })
                .selectAll(true)
              Button('󰈱')
                .onClick(() => {
                  clearTimeout(this.refreshForResourcesTimeout);
                  this.search(this.meowDictExampleMDX, this.lookUpWordMDX);
                })
            } // Search bar
            .id('searchBar')
            .alignRules(this.wideMode ?
              { left: { anchor: 'fileControlButtons', align: HorizontalAlign.End }, right: { anchor: '__container__', align: HorizontalAlign.End }, bottom: { anchor: '__container__', align: VerticalAlign.Bottom } } :
              { left: { anchor: '__container__', align: HorizontalAlign.Start }, right: { anchor: '__container__', align: HorizontalAlign.End }, bottom: { anchor: '__container__', align: VerticalAlign.Bottom } })
            .animation({ curve: Curve.ExtremeDeceleration, duration: 200 })

          }
          .height(this.wideMode ? 40 : 90)
          .animation({ curve: Curve.ExtremeDeceleration, duration: 200 })

          Web({ controller: this.webController, src: '' })
            .darkMode(WebDarkMode.Auto)
            .forceDarkAccess(true)
            .javaScriptAccess(true)
            .imageAccess(true)
            .onlineImageAccess(true)
            .mixedMode(MixedMode.All)
            .fileAccess(true)
            .domStorageAccess(true)
            .databaseAccess(true)
            .allowWindowOpenMethod(true)
            .multiWindowAccess(true)
            .layoutWeight(1)
            .borderRadius(10)
            .onInterceptRequest((e) => {
              const reqUrl = e.request.getRequestUrl();
              const reqFilePath = reqUrl.split('/');
              const reqFileName = reqFilePath[reqFilePath.length-1];
              const reqFileScheme = reqFilePath[0];

              if (reqFileScheme == 'file:') {
                fileIo.access(this.getUIContext().getHostContext()!.filesDir + '/meow/' + reqFileName).catch((e: BusinessError) => {
                  console.error(`[Meow][Web][onInterceptRequest] fileIo.access() failed: ${e}`);
                }).then((r) => {
                  if (r) {
                    // console.log(`[Meow][Web][onInterceptRequest] file '${reqFileName}' exist! Reusing...`);
                    return;
                  }

                  if (reqUrl.length < 256) {
                    console.warn(`[Meow][Web][onInterceptRequest] ${reqUrl}, reqFileScheme = ${reqFileScheme}, reqFileName = ${reqFileName}`);
                  } else {
                    console.warn(`[Meow][Web][onInterceptRequest][long] reqFileScheme = ${reqFileScheme}`);
                  }

                  // Read
                  this.extractFile(this.meowDictExampleMDD, '\\' + reqFileName).then((r) => {
                    if (!r) {
                      console.error(`[Meow][Web][refreshForResourcesTimeout] Reource not found! Not going to refresh!`);
                      return;
                    }
                    // Loaded resource
                    clearTimeout(this.refreshForResourcesTimeout);
                    this.refreshForResourcesTimeout = setTimeout(() => {
                      try {
                        console.warn(`[Meow][Web][refreshForResourcesTimeout] Refresh!`);
                        this.refreshForResourcesTimeout = undefined;
                        this.webController.refresh();
                      } catch (e) {
                        console.error(`[Meow][Web][refreshForResourcesTimeout] failed: ${e}`);
                      }
                    }, 100);
                  })
                })
              } else if (reqFileScheme == 'entry:') {
                clearTimeout(this.refreshForResourcesTimeout);
                this.search(this.meowDictExampleMDX, decodeURIComponent(reqFileName));
                this.lookUpWordMDX = decodeURIComponent(reqFileName);
              }

              return null;
            })
            .onControllerAttached(() => {
              this.loadWeb(this.meowDictExampleMDX?.header?.toHtml());
            })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .enabled(this.render)
        .opacity(this.render ? 1 : 0.5)
        .margin(this.myMeowFreeWindowModeStatus.on ? {} : this.myMeowAvoid)
        .padding(this.myMeowFreeWindowModeStatus.on ? { left: 10, bottom: 10, right: 10 } : 10)
      }
    }
    .useEffect(this.myMeowFreeWindowModeStatus.on, EffectType.WINDOW_EFFECT)
    .onAppear(() => {
      this.render = true;
    })
    .onAreaChange((o, n) => {
      if (o.width != n.width) {
        this.windowWidth = n.width as number;
        this.wideMode = this.windowWidth > 800;
      }
      if (o.height != n.height) {
        this.windowHeight = n.height as number;
      }
    })
  }

  loadWeb(content: string | undefined) {
    if (!content) {
      return;
    }

    try {
      this.webController.loadData(content, 'text/html', 'UTF-8', 'file://' + this.getUIContext().getHostContext()!.filesDir + '/meow/', ' ');
    } catch (e) {
      console.error(`[Meow] loadWeb() Failed! ${e}`);
    }
  }

  search(dict: meowDict | undefined, key: string) {
    if (!dict || !dict.isReady()) {
      return;
    }

    const query = keepOnlyAlphanumericGlobal(key.toLowerCase());
    dict.lookUpKey(query, true).then((resultBuffer) => {
      if (!resultBuffer) {
        // Not found
        return;
      }
      if (dict.type == meowDictType.MDX) {
        let resultText = resultBuffer.toString(dict.header!.Encoding);
        this.loadWeb(resultText);
        console.log(`[Meow][MDX] Got result!`);

        this.keywordsInSameIndexBlock = this.meowDictExampleMDX?.keyword?.index?.indexEntries[this.meowDictExampleMDX?.keyword?.lookUpBlockIndex].builtBlock?.keywords || [];
        console.log(`[Meow][MDX] this.keywordsInSameIndexBlock.length = ${this.keywordsInSameIndexBlock.length}`);

        let re: string[] = [];
        for (let wordIndex = 0; wordIndex < this.keywordsInSameIndexBlock.length; wordIndex++) {
          if (keepOnlyAlphanumericGlobal(this.keywordsInSameIndexBlock[wordIndex].toLowerCase()).includes(query)) {
            re.push(this.keywordsInSameIndexBlock[wordIndex]);
            // console.log(`[Meow][MDX] Relative: ${this.keywordsInSameIndexBlock[wordIndex]}`);
          }
        }
        this.keywordsInSameIndexBlockRelative = re;
        const percentage = this.keywordsInSameIndexBlockRelative.length / this.keywordsInSameIndexBlock.length * 100;
        console.log(`[Meow][MDX] this.keywordsInSameIndexBlockRelative.length = ${this.keywordsInSameIndexBlockRelative.length} (${percentage.toFixed(2)} %)`);
        // console.log(`[Meow][MDX] this.keywordsInSameIndexBlockRelative: ${'\n' + this.keywordsInSameIndexBlockRelative}`);

      } else if (dict.type == meowDictType.MDD) {
        console.log(`[Meow][MDD] Got result!`);
      }
    })

  }

  /**
   * Extracts a file from a dictionary.
   * @param dict The dictionary.
   * @param key The key.
   * @returns True if success.
   * */
  async extractFile(dict: meowDict | undefined, key: string) {
    return dict?.lookUpKey(key, false).then((resultBuffer) => {
      if (!resultBuffer) {
        return false;
      }
      if (dict.type == meowDictType.MDD) {
        // console.log(`[Meow][MDD] Got result! ${resultBuffer}`);

        let fileName = key;
        if (fileName.substring(0, 1) == '\\') {
          fileName = fileName.substring(1);
        }
        sandboxSaveSync('meow/' + fileName, resultBuffer.buffer, this.getUIContext().getHostContext()!);
      }
      return true;
    })
  }
}