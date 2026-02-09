import { meowDictType } from '../hosts/meowDict';
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { defaultAnima, defaultDecorHeight, meowAvoid, meowFreeWindowModeStatus, meowLayoutModeStatus } from '../utils/uiEnv';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize, keepOnlyAlphanumericGlobal, mimeOfFileName, resource_to_string } from '../utils/data';
import { meowTheme } from '../hosts/meowTheme';
import lazy { playThisForMe } from '../utils/av';
import lazy { fastbuffer } from '@kit.ArkTS';
import meowBundleInfo from '../components/MeowBundleInfo';
import { meowDictBundle } from '../hosts/meowDictBundle';
import { meowDictBundleLibrarian } from '../hosts/meowDictBundleLibrarian';

@Entry
@ComponentV2
struct Index {
  @Local myMeowAvoid: meowAvoid = AppStorageV2.connect<meowAvoid>(meowAvoid)!;
  @Local myMeowFreeWindowModeStatus: meowFreeWindowModeStatus = AppStorageV2.connect<meowFreeWindowModeStatus>(meowFreeWindowModeStatus)!;
  @Local myMeowLayout: meowLayoutModeStatus = AppStorageV2.connect<meowLayoutModeStatus>(meowLayoutModeStatus)!;
  @Local windowTopAvoid: number = 0;
  // Data
  @Local meowDictExampleBundle: meowDictBundle = AppStorageV2.connect<meowDictBundle>(meowDictBundle, 'meowDictExampleBundle', () => new meowDictBundle())!;
  @Local meowLibrarian: meowDictBundleLibrarian = AppStorageV2.connect<meowDictBundleLibrarian>(meowDictBundleLibrarian, 'meowDictBundleLibrarian', () => new meowDictBundleLibrarian())!;
  // Runtime interaction
  @Local lookUpWord: string = '';
  @Local lookUpResult: boolean = true;
  @Local keywordsInSameIndexBlock: string[] = [];
  @Local keywordsInSameIndexBlockRelevant: string[] = [];
  // Runtime UI
  @Local topDown: boolean = this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode;
  @Local render: boolean = false;
  @Local renderWeb: boolean = false;
  @Local renderMore: boolean = false;
  @Local firstPageLoaded: boolean = false;
  @Local linearBlurOps: LinearGradientBlurOptions = this.constructLinearBlurOps();
  @Local showInfo: boolean = false;
  timeoutIdForAvoidReload: number | undefined;
  @Local buttonsWidth: number = 0;
  // Runtime Objects
  webController: WebviewController = new webview.WebviewController();
  context: Context = this.getUIContext().getHostContext()!;
  currentDictNo: number = 0;

  aboutToAppear(): void {
    console.warn(`[UI][aboutToAppear] TopDown: ${this.topDown}`);
  }

  build() {
    WithTheme({ theme: new meowTheme() }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.render) {
          Stack() {
            if (this.renderWeb) {
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
                .onLoadIntercept((e) => {
                  const reqUrl = e.data.getRequestUrl();
                  const reqFilePath = reqUrl.split('/');
                  const reqFileName = decodeURIComponent(reqFilePath.slice(1).join('\\'));
                  const reqFileScheme = reqFilePath[0];

                  if (['sound:'].includes(reqFileScheme)) {
                    if (reqUrl.length < 256) {
                      console.warn(`[Meow][Web][onLoadIntercept][${reqUrl}], reqFileScheme = ${reqFileScheme}, reqFileName = ${reqFileName}`);
                    } else {
                      console.warn(`[Meow][Web][onLoadIntercept][long] reqFileScheme = ${reqFileScheme}`);
                    }

                    // Load
                    this.meowLibrarian.bundles[this.currentDictNo]?.extractFileToTemp(reqFileName, this.context)
                      .then(async (r) => {
                        if (r) {
                          playThisForMe(r, `[Meow][Web][onLoadIntercept][Media][${reqUrl}]`);
                        } else {
                          console.warn(`[Meow][Web][onLoadIntercept][${reqUrl}] Not found.`);
                        }
                      })

                    return true;
                  }

                  return false;
                })
                .onInterceptRequest((e) => {
                  const reqUrl = e.request.getRequestUrl();
                  const reqFilePath = reqUrl.split('/');
                  const reqFileScheme = reqFilePath[0];

                  // Process file name
                  let reqFileName = 'name';
                  const base = reqFileScheme + '//' + this.currentBase();
                  if (reqUrl.indexOf(base) == 0) {
                    reqFileName = reqUrl.substring(base.length);
                  } else {
                    reqFileName = reqUrl.substring((reqFileScheme + '//').length);
                  }
                  reqFileName = decodeURIComponent(reqFileName);

                  console.log(`[Meow][Web][onInterceptRequest][${reqUrl}] ${reqFileName}`);

                  // Process according to schemes
                  if (reqFileScheme == 'file:') {
                    reqFileName = reqFileName.replaceAll('/', '\\');

                    // Check existence
                    let exist = false;
                    try {
                      exist = fileIo.accessSync(this.currentBase() + reqFileName);
                    } catch (e) {
                      console.error(`[Meow][Web][onInterceptRequest] fileIo.accessSync() failed: ${e}`);
                    }
                    if (exist) {
                      // console.log(`[Meow][Web][onInterceptRequest][${reqUrl}] file '${reqFileName}' exist!`);
                      return null;
                    }

                    // Get the files
                    let response = new WebResourceResponse();
                    let regularFileName = reqFileName;
                    if (regularFileName.substring(0, 1) != '\\') {
                      regularFileName = '\\' + regularFileName;
                    }
                    this.meowLibrarian.bundles[this.currentDictNo]?.lookUpResourceFromMDDs(regularFileName)
                      .then((resultBuffer) => {
                        if (resultBuffer) {
                          console.log(`[Meow][Web][onInterceptRequest][${reqUrl}][${regularFileName}] Loaded. (${addUnitsToSize(resultBuffer.byteLength)})`);
                          response.setResponseData(resultBuffer);
                          response.setResponseMimeType(mimeOfFileName(regularFileName));
                        } else {
                          console.warn(`[Meow][Web][onInterceptRequest][${reqUrl}][${regularFileName}] Not found.`);
                        }
                        response.setResponseIsReady(true);
                      })

                    // Response
                    response.setResponseIsReady(false);
                    return response;
                  }

                  if (reqFileScheme == 'entry:') {
                    this.searchMDX(this.meowLibrarian.bundles[this.currentDictNo], decodeURIComponent(reqFileName));
                  }

                  return null;
                })
                .borderRadius(15)
                .backgroundColor(Color.Transparent)
                .id('mainWeb')
                .linearGradientBlur(30, this.linearBlurOps)
            }

            Column({ space: 8 }) {
              Button(`󰀵 ${resource_to_string($r('app.string.new_dictionary'), this.context)}`)
                .onClick(() => {
                  this.meowLibrarian.createBundle(this.context);
                })

              if (this.renderMore) {
                Scroll() {
                  Column({ space: 8 }) {
                    if (this.meowDictExampleBundle.mdx?.header) {
                      meowBundleInfo({
                        bundle: this.meowDictExampleBundle,
                        deleteAction: () => {
                          fileIo.rmdir(this.context.filesDir + '/meow/')
                            .catch((e: BusinessError) => {
                              console.error(`[Meow][Legacy] fileIo.rmdir(this.context.filesDir + '/meow/') Failed: ${e}`);
                            });
                          fileIo.rmdir(this.context.filesDir + '/woof/')
                            .catch((e: BusinessError) => {
                              console.error(`[Meow][Legacy] fileIo.rmdir(this.context.filesDir + '/woof/') Failed: ${e}`);
                            });
                          fileIo.rmdir(this.context.filesDir + '/honk/')
                            .catch((e: BusinessError) => {
                              console.error(`[Meow][Legacy] fileIo.rmdir(this.context.filesDir + '/honk/') Failed: ${e}`);
                            });
                          this.meowDictExampleBundle = new meowDictBundle();
                        }
                      })
                    }

                    ForEach(this.meowLibrarian.bundles, (bundle: meowDictBundle, idx: number) => {
                      meowBundleInfo({
                        bundle: bundle,
                        deleteAction: () => {
                          this.meowLibrarian.deleteBundle(idx, this.context);
                        }
                      })
                    }, (bundle: meowDictBundle) => {
                      return bundle.sandboxPathWithEndSlash;
                    })
                  }
                }
                .width('100%')
                .align(Alignment.Top)
                .layoutWeight(1)
                .scrollable(ScrollDirection.Vertical)
                .edgeEffect(EdgeEffect.Spring)
                .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
              }
            } // More panel
            .visibility(this.showInfo ? Visibility.Visible : Visibility.None)
            .animation(defaultAnima)
            .alignItems(HorizontalAlign.Start)
            .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 15 : 30)
            .borderWidth(1)
            .borderColor($r('sys.color.comp_background_tertiary'))
            .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
            .padding(10)
            .margin({
              left: 10,
              bottom: this.topDown ? 10 : this.myMeowAvoid.bottom + this.titleHeight() + 10,
              right: 10,
              top: this.topDown ? this.myMeowAvoid.top + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0) + this.titleHeight() + 10 : this.windowTopAvoid + 10
            })
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)

            RelativeContainer() {
              Scroll() {
                Row({ space: 10 }) {
                  Button(`󰊖 ${resource_to_string($r('app.string.info'), this.context)}`)
                    .onClick(() => {
                      this.renderMore = true;
                      this.showInfo = !this.showInfo;
                    })
                    .border(this.showInfo ? { width: 2, color: $r('app.color.button_border') } : { width: 2, color: Color.Transparent })
                    .brightness(this.showInfo ? 1.1 : 1)
                    .animation(defaultAnima)

                  ForEach(this.meowLibrarian.bundles, (bundle: meowDictBundle, index: number) => {
                    if (bundle.mdx) {
                      Button(`${bundle.mdx?.header?.Title}`)
                        .onClick(() => {
                          this.currentDictNo = index;
                          this.searchMDX(bundle, this.lookUpWord);
                        })
                    }
                  })
                } // Buttons
                .onAreaChange((o, n) => {
                  if (o.width != n.width) {
                    this.buttonsWidth = n.width as number;
                  }
                })
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
              .id('fileControlButtons')
              .alignRules({ left: { anchor: '__container__', align: HorizontalAlign.Start }, top: { anchor: '__container__', align: VerticalAlign.Top } })
              .animation(defaultAnima)

              Row({ space: 10 }) {
                TextInput({ placeholder: `󰀩 ${this.meowLibrarian.bundles[this.currentDictNo]?.mdx?.header?.Title || ''}`, text: this.lookUpWord })
                  .layoutWeight(1)
                  .onChange((e) => {
                    this.lookUpWord = e;
                  })
                  .onSubmit(() => {
                    this.currentDictNo = 0;
                    this.searchMDX(this.meowLibrarian.bundles[this.currentDictNo], this.lookUpWord).then((result) => {
                      this.lookUpResult = result == true;
                    })
                  })
                  .selectAll(true)
                  .selectedBackgroundColor($r('sys.color.font'))
                  .keyboardAppearance(KeyboardAppearance.IMMERSIVE)

                Button(`${this.lookUpResult ? '' : '¯\\_(ツ)_/¯  '}󰈱`)
                  .onClick(() => {
                    this.currentDictNo = 0;
                    this.searchMDX(this.meowLibrarian.bundles[this.currentDictNo], this.lookUpWord).then((result) => {
                      this.lookUpResult = result == true;
                    })
                  })
              } // Search bar
              .padding(this.twoRows() ? { left: 10 } : {})
              .id('searchBar')
              .alignRules(this.twoRows() ?
                { left: { anchor: 'fileControlButtons', align: HorizontalAlign.End }, right: { anchor: '__container__', align: HorizontalAlign.End }, bottom: { anchor: '__container__', align: VerticalAlign.Bottom } } :
                { left: { anchor: '__container__', align: HorizontalAlign.Start }, right: { anchor: '__container__', align: HorizontalAlign.End }, bottom: { anchor: '__container__', align: VerticalAlign.Bottom } })
              .animation(defaultAnima)

            } // Title
            .height(this.titleHeight())
            .animation(defaultAnima)
            .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 15 : 30)
            .borderWidth(1)
            .borderColor($r('sys.color.comp_background_tertiary'))
            .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
            .padding(10)
            .margin({
              left: 10,
              bottom: this.myMeowAvoid.bottom,
              right: 10,
              top: this.myMeowAvoid.top + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0)
            })
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          }
          .height('100%')
          .width('100%')
          .alignContent(this.topDown ? Alignment.Top : Alignment.Bottom)
          .animation(defaultAnima)
        }

        if (this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode) {
          Text(this.meowLibrarian.bundles[this.currentDictNo]?.mdx?.header?.Title)
            .padding(10)
            .width('100%')
            .textAlign(TextAlign.Center)
            .textVerticalAlign(TextVerticalAlign.TOP)
            .align(Alignment.Top)
        } // Title
      }
      .useEffect(this.myMeowFreeWindowModeStatus.on, EffectType.WINDOW_EFFECT)
      .width('100%')
      .height('100%')
      .animation(defaultAnima)
      .onAreaChange((o, n) => {
        if (o.width != n.width) {
          this.myMeowLayout.width = n.width as number;
          this.myMeowLayout.wideMode = this.myMeowLayout.width > 900;
        }
        if (o.height != n.height) {
          this.myMeowLayout.height = n.height as number;
        }

        if (o.width != n.height || o.width != n.width) {
          // Anyone update
          this.refreshWebToUpdateAvoid();
        }
      })
      .onAppear(() => {
        // this.refreshUIParams();
        setTimeout(() => {
          this.render = true;
          setTimeout(() => {
            if (!this.renderWeb) {
              this.renderWeb = true;
            }
          }, 500)
        }, 10)
      })
    }
  }

  // Actions

  loadWeb(content: string | undefined, base: string = this.context.filesDir + '/') {
    if (!content) {
      return false;
    }

    const avoidPercentages = this.constructWebAvoidPercentages();
    const padTop = `<div id='dictionareowTopAvoid' style="height: ${avoidPercentages[0]}%"></div>`;
    const padBottom = `<div id='dictionareowBottomAvoid' style="height: ${avoidPercentages[1]}%"></div>`;

    console.log(`[Meow][loadWeb] base is ${'file://' + base}`);

    try {
      // this.currentBase = base + 'meow/';
      this.webController.loadData(padTop + content + padBottom, 'text/html', 'UTF-8', 'file://' + base, ' ');
      console.log(content);
      return true;
    } catch (e) {
      console.error(`[Meow] loadWeb() Failed! ${e}`);
      return false;
    }
  }

  async searchMDX(bundle: meowDictBundle | undefined, key: string) {
    if (!bundle || !bundle.mdx || !bundle.mdx.isReady()) {
      return false;
    }

    while (key.substring(0, 8) == 'entry://') {
      key = key.substring(8);
    }

    // TODO: Finish # Jumps
    const keySplit = key.split('#');
    key = keySplit[keySplit.length-1];
    if (this.lookUpWord != key) {
      this.lookUpWord = key;
    }

    if (!this.renderWeb) {
      this.renderWeb = true;
    }

    const query = keepOnlyAlphanumericGlobal(key.toLowerCase());
    return bundle.mdx.lookUpKey(query)?.then((resultBuffer) => {
      if (!resultBuffer) {
        // Not found
        return false;
      }
      if (bundle.mdx!.type == meowDictType.MDX) {
        let resultText = 'ERROR! ＞︿＜';
        try {
          resultText = fastbuffer.from(resultBuffer).toString(bundle.mdx!.header!.Encoding);
        } catch (e) {
          console.error(`[Meow][MDX] Error for resultText = resultBuffer.toString(dict.header!.Encoding);! ${e}`);
        }
        this.loadWeb(resultText, this.currentBase());
        // console.log(`[Meow][MDX] Got result!`);

        this.keywordsInSameIndexBlock = bundle.mdx?.keyword?.index?.indexEntries[bundle.mdx?.keyword?.lookUpBlockIndex].builtBlock?.keywords || [];
        console.log(`[Meow][MDX] this.keywordsInSameIndexBlock.length = ${this.keywordsInSameIndexBlock.length}`);

        let re: string[] = [];
        for (let wordIndex = 0; wordIndex < this.keywordsInSameIndexBlock.length; wordIndex++) {
          if (keepOnlyAlphanumericGlobal(this.keywordsInSameIndexBlock[wordIndex].toLowerCase()).includes(query)) {
            re.push(this.keywordsInSameIndexBlock[wordIndex]);
            // console.log(`[Meow][MDX] Relative: ${this.keywordsInSameIndexBlock[wordIndex]}`);
          }
        }
        this.keywordsInSameIndexBlockRelevant = re;
        const percentage = this.keywordsInSameIndexBlockRelevant.length / this.keywordsInSameIndexBlock.length * 100;
        console.log(`[Meow][MDX][${query}] this.keywordsInSameIndexBlockRelevant.length = ${this.keywordsInSameIndexBlockRelevant.length} (${percentage.toFixed(2)} %)`);
        console.log(`[Meow][MDX][${query}] this.keywordsInSameIndexBlockRelevant: ${'\n' + this.keywordsInSameIndexBlockRelevant}`);
      }

      return true;
    })
  }

  /**
   * Extracts a file from a dictionary to sandbox temp.
   * @param dict The dictionary.
   * @param key The key.
   * @returns True if success.
   * */

  // Data

  /**
   * Determines the title bar height.
   * @returns 60 or 110.
   * */
  titleHeight() {
    return this.twoRows() ? 60 : 110;
  }

  twoRows() {
    return (this.myMeowLayout.wideMode && (this.buttonsWidth < 0.8 * this.myMeowLayout.width));
  }

  /**
   * Constructs the linear blur options for top blur.
   * @returns The options.
   * */
  constructLinearBlurOps() {
    return {
      fractionStops: [
        [1, 0],
        [1, this.windowTopAvoid / this.myMeowLayout.height],
        [0, (this.windowTopAvoid + (this.topDown ? this.titleHeight() : 1)) / this.myMeowLayout.height],
      ],
      direction: GradientDirection.Bottom
    } as LinearGradientBlurOptions;
  }

  /**
   * Calculates the avoid params for web (including the title bar).
   * @returns [topPercentage, bottomPercentage]
   * */
  constructWebAvoidPercentages() {
    let topVp = this.windowTopAvoid;
    let bottomVp = this.myMeowAvoid.bottom;

    if (this.topDown) {
      topVp += this.titleHeight() + 10;
    } else {
      bottomVp += this.titleHeight();
    }

    const topPercentage = topVp / this.myMeowLayout.height * 100;
    const bottomPercentage = bottomVp / this.myMeowLayout.height * 100;

    return [topPercentage, bottomPercentage];
  }

  currentBase() {
    return this.context.filesDir + '/' + this.meowLibrarian.bundles[this.currentDictNo]?.sandboxPathWithEndSlash + 'meow/';
  }

  // Events

  @Monitor('myMeowFreeWindowModeStatus.on', 'myMeowAvoid.top', 'myMeowLayout.height', 'myMeowLayout.width', 'myMeowLayout.wideMode', 'buttonsWidth')
  refreshUIParams() {
    console.log(`[Meow][web][refreshUIParams] !`);
    this.topDown = this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode;
    this.windowTopAvoid = this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : this.myMeowAvoid.top;
    this.linearBlurOps = this.constructLinearBlurOps();
  }

  @Monitor('myMeowAvoid.top', 'buttonsWidth')
  refreshWebToUpdateAvoid() {
    if (!this.renderWeb) {
      return;
    }
    // console.log(`[Meow][web][refreshWebToUpdateAvoid] !`);
    clearTimeout(this.timeoutIdForAvoidReload);
    this.timeoutIdForAvoidReload = setTimeout(() => {
      // this.loadWeb(this.currentContent);
      const avoidPercentages = this.constructWebAvoidPercentages();
      this.webController.runJavaScript(`document.getElementById('dictionareowTopAvoid').style.height = "${avoidPercentages[0]}%"`).catch((e: BusinessError) => {
        console.error(`[Meow][web][refreshWebToUpdateAvoid] this.webController.runJavaScript Top failed: ${e}`);
      });
      this.webController.runJavaScript(`document.getElementById('dictionareowBottomAvoid').style.height = "${avoidPercentages[1]}%"`).catch((e: BusinessError) => {
        console.error(`[Meow][web][refreshWebToUpdateAvoid] this.webController.runJavaScript Bottom failed: ${e}`);
      });
    }, 10);
  }
}