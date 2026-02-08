import { meowDict, meowDictBundle, meowDictType } from '../hosts/meowDict';
import { fileCopy, fileDocumentPick2Path } from '../utils/storage';
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { defaultAnima, defaultDecorHeight, meowAvoid, meowFreeWindowModeStatus, meowLayoutModeStatus } from '../utils/uiEnv';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize, keepOnlyAlphanumericGlobal, mimeOfFileName, resource_to_string } from '../utils/data';
import { meowTheme } from '../hosts/meowTheme';
import MeowDictInfo from '../components/MeowDictInfo';
import { playThisForMe } from '../utils/av';
import MeowFileInfo from '../components/MeowFileInfo';
import { buffer, fastbuffer } from '@kit.ArkTS';

@Entry
@ComponentV2
struct Index {
  @Local myMeowAvoid: meowAvoid = AppStorageV2.connect<meowAvoid>(meowAvoid)!;
  @Local myMeowFreeWindowModeStatus: meowFreeWindowModeStatus = AppStorageV2.connect<meowFreeWindowModeStatus>(meowFreeWindowModeStatus)!;
  @Local myMeowLayout: meowLayoutModeStatus = AppStorageV2.connect<meowLayoutModeStatus>(meowLayoutModeStatus)!;
  @Local windowTopAvoid: number = 0;
  // Data
  @Local meowDictExampleBundle: meowDictBundle = AppStorageV2.connect<meowDictBundle>(meowDictBundle, 'meowDictExampleBundle', () => new meowDictBundle())!;
  // Runtime interaction
  @Local lookUpWord: string = '';
  @Local lookUpResult: boolean = true;
  @Local keywordsInSameIndexBlock: string[] = [];
  @Local keywordsInSameIndexBlockRelevant: string[] = [];
  refreshForRefreshFilesTimeout: number | undefined;
  currentContent: string = '';
  // Runtime UI
  @Local topDown: boolean = this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode;
  @Local render: boolean = false;
  @Local firstPageLoaded: boolean = false;
  @Local linearBlurOps: LinearGradientBlurOptions = this.constructLinearBlurOps();
  @Local showInfo: boolean = false;
  timeoutIdForAvoidReload: number | undefined;
  // Runtime Objects
  webController: WebviewController = new webview.WebviewController();
  context: Context = this.getUIContext().getHostContext()!;

  build() {
    WithTheme({ theme: new meowTheme() }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.render) {
          Stack() {
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
                  this.meowDictExampleBundle.extractFileToTemp(reqFileName, this.context).then(async (r) => {
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
                const base = reqFileScheme + '//' + this.context.filesDir + '/meow/';
                if (reqUrl.indexOf(base) == 0) {
                  reqFileName = reqUrl.substring(base.length);
                } else {
                  reqFileName = reqUrl.substring((reqFileScheme + '//').length);
                }
                reqFileName = decodeURIComponent(reqFileName);

                // Process according to schemes
                if (reqFileScheme == 'file:') {
                  reqFileName = reqFileName.replaceAll('/', '\\');

                  // Check existence
                  let exist = false;
                  try {
                    exist = fileIo.accessSync(this.context.filesDir + '/meow/' + reqFileName);
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
                  this.meowDictExampleBundle.lookUpResourceFromMDDs(regularFileName).then((resultBuffer) => {
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
                  this.searchMDX(this.meowDictExampleBundle, decodeURIComponent(reqFileName));
                }

                return null;
              })
              .onControllerAttached(() => {
                if (!this.firstPageLoaded) {
                  console.log(`[Meow][MDX] Woof! From onControllerAttached!`);
                  this.firstPageLoaded = true;
                  this.loadWeb(this.meowDictExampleBundle.mdx?.header?.toHtml());
                }
              })
              .borderRadius(15)
              .backgroundColor(Color.Transparent)
              .id('mainWeb')
              .linearGradientBlur(30, this.linearBlurOps)

            Row() {
              WaterFlow() {
                if (this.meowDictExampleBundle.mdx) {
                  MeowDictInfo({
                    dict: this.meowDictExampleBundle.mdx,
                    deleteAction: () => {
                      fileIo.unlink(this.meowDictExampleBundle.mdx!.fullPath)
                        .catch((e: BusinessError) => {
                          console.error(`[Meow][Info] fileIo.unlink(this.meowDictExampleBundle.mdds[index].fullPath) Failed: ${e}`);
                        });
                      this.meowDictExampleBundle.mdx = undefined;
                    }
                  })
                }
                ForEach(this.meowDictExampleBundle.mdds, ((mdd: meowDict, index: number) => {
                  MeowDictInfo({
                    dict: mdd,
                    deleteAction: () => {
                      fileIo.unlink(this.meowDictExampleBundle.mdds[index].fullPath)
                        .catch((e: BusinessError) => {
                          console.error(`[Meow][Info] fileIo.unlink(this.meowDictExampleBundle.mdds[index].fullPath) Failed: ${e}`);
                        });
                      this.meowDictExampleBundle.mdds.splice(index, 1);
                    }
                  })
                }))
                ForEach(this.meowDictExampleBundle.files, ((path: string, index: number) => {
                  MeowFileInfo({
                    filePath: path,
                    fileSize: this.meowDictExampleBundle.fileSizes[index],
                    deleteAction: () => {
                      fileIo.unlink(path)
                        .catch((e: BusinessError) => {
                          console.error(`[Meow][Info][Files] fileIo.unlink(path) Failed: ${e}`);
                        });
                      this.meowDictExampleBundle.updateFiles(this.context);
                    }
                  })
                }))
              } // Info
              .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
              .columnsGap(10)
              .rowsGap(10)
              .columnsTemplate("1fr ".repeat(Math.ceil(this.myMeowLayout.width / 500)))
              .edgeEffect(EdgeEffect.Spring)
              .animation(defaultAnima)

            }
            .visibility(this.showInfo ? Visibility.Visible : Visibility.None)
            // .height(Math.min(0.8 * this.myMeowLayout.height, this.myMeowLayout.height - this.titleHeight() - 20 - this.windowTopAvoid))
            .constraintSize({ maxHeight: this.myMeowLayout.height - this.titleHeight() - 20 - this.windowTopAvoid })
            .animation(defaultAnima)
            .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 15 : 30)
            .borderWidth(1)
            .borderColor($r('sys.color.comp_background_tertiary'))
            .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
            .padding(10)
            .margin({
              left: 10,
              bottom: this.myMeowAvoid.bottom + this.titleHeight() + 10,
              right: 10,
              top: this.myMeowAvoid.top + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0) + this.titleHeight() + 10
            })
            .shadow(ShadowStyle.OUTER_DEFAULT_SM)

            RelativeContainer() {
              Scroll() {
                Row({ space: 10 }) {
                  Button(this.meowDictExampleBundle.mdx?.header ? 'MDX  󰀓' : '󰀵 MDX')
                    .onClick(() => {
                      fileDocumentPick2Path(['.mdx'], 1).then((r) => {
                        if (r.succeed) {
                          const sourcePath = r.sourcePaths![0];
                          const destPath: string = this.context.filesDir + '/woof/woof.mdx';
                          fileCopy(sourcePath, destPath).then(() => {
                            this.meowDictExampleBundle.mdx = new meowDict(meowDictType.MDX, destPath);
                            this.meowDictExampleBundle.mdx.init();
                            console.log(`[Meow][Files][MDX][${sourcePath}][${destPath}]`);
                          })
                          // sandboxSaveHybrid('woof/woof.mdx', r.buf!, this.context, true);
                        }
                      })
                    })
                  Button(`󰀵 MDD (${this.meowDictExampleBundle.mdds.length})`)
                    .onClick(() => {
                      fileDocumentPick2Path(['.mdd'], 233).then((r) => {
                        if (r.succeed) {
                          for (let index = 0; index < r.sourcePaths!.length; index++) {
                            // Save (copy) file
                            const sourcePath = r.sourcePaths![index];
                            const targetPathSplit = sourcePath.split('/');
                            const fileName: string | undefined = targetPathSplit[targetPathSplit.length-1];
                            const destPath = this.context.filesDir + '/honk/' + fileName;
                            fileCopy(sourcePath, destPath).then(() => {
                              // Create object
                              let mdd = new meowDict(meowDictType.MDD, destPath);
                              this.meowDictExampleBundle.mdds.push(mdd);
                              mdd.init();
                              console.log(`[Meow][Files][MDD][${index}][${sourcePath}][${destPath}][${fileName}]`);
                            })
                          }
                        }
                      })
                    })
                  Button(`󰀵 ${resource_to_string($r('app.string.add_files'), this.context)} (${this.meowDictExampleBundle.files.length})`)
                    .onClick(() => {
                      fileDocumentPick2Path([], 233).then((r) => {
                        if (r.succeed) {
                          for (let index = 0; index < r.sourcePaths!.length; index++) {
                            const sourcePath = r.sourcePaths![index];
                            const targetPathSplit = sourcePath.split('/');
                            const fileName: string | undefined = targetPathSplit[targetPathSplit.length-1];
                            fileCopy(sourcePath, this.context.filesDir + '/meow/' + fileName).then(() => {
                              clearTimeout(this.refreshForRefreshFilesTimeout);
                              this.refreshForRefreshFilesTimeout = setTimeout(() => {
                                this.meowDictExampleBundle.updateFiles(this.context);
                              }, 200)
                            })
                            // sandboxSaveHybrid('meow/' + r.fileName!, r.buf!, this.context, true);
                            console.log(`[Meow][Files][${sourcePath}][${fileName}]`);
                          }
                        }
                      })
                    })
                  Button(`󰊖 ${resource_to_string($r('app.string.info'), this.context)}`)
                    .onClick(() => {
                      this.showInfo = !this.showInfo;
                    })
                    .border(this.showInfo ? { width: 2, color: $r('app.color.button_border') } : { width: 2, color: Color.Transparent })
                    .brightness(this.showInfo ? 1.1 : 1)
                    .animation(defaultAnima)
                } // Buttons
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
              .id('fileControlButtons')
              .alignRules({ left: { anchor: '__container__', align: HorizontalAlign.Start }, top: { anchor: '__container__', align: VerticalAlign.Top } })
              .animation(defaultAnima)

              Row({ space: 10 }) {
                TextInput({ placeholder: `󰀩 ${this.meowDictExampleBundle.mdx?.header?.Title || ''}`, text: this.lookUpWord })
                  .layoutWeight(1)
                  .onChange((e) => {
                    this.lookUpWord = e;
                  })
                  .onSubmit(() => {
                    this.searchMDX(this.meowDictExampleBundle, this.lookUpWord).then((result) => {
                      this.lookUpResult = result == true;
                    })
                  })
                  .selectAll(true)
                  .selectedBackgroundColor($r('sys.color.font'))
                  .keyboardAppearance(KeyboardAppearance.IMMERSIVE)

                Button(`${this.lookUpResult ? '' : '¯\\_(ツ)_/¯  '}󰈱`)
                  .onClick(() => {
                    this.searchMDX(this.meowDictExampleBundle, this.lookUpWord).then((result) => {
                      this.lookUpResult = result == true;
                    })
                  })
              } // Search bar
              .padding(this.myMeowLayout.wideMode ? { left: 10 } : {})
              .id('searchBar')
              .alignRules(this.myMeowLayout.wideMode ?
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
          .alignContent(this.topDown ? Alignment.Top : Alignment.Bottom)
          .animation(defaultAnima)

          if (this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode) {
            Text(this.meowDictExampleBundle.mdx?.header?.Title)
              .padding(10)
              .width('100%')
              .textAlign(TextAlign.Center)
              .textVerticalAlign(TextVerticalAlign.TOP)
              .align(Alignment.Top)
          }
        }
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
        this.render = true;
        this.refreshUIParams();
      })
    }
  }

  // Actions

  loadWeb(content: string | undefined) {
    if (!content) {
      return false;
    }

    this.currentContent = content;

    const avoidPercentages = this.constructWebAvoidPercentages();

    const padTop = `<div id='dictionareowTopAvoid' style="height: ${avoidPercentages[0]}%"></div>`;
    const padBottom = `<div id='dictionareowBottomAvoid' style="height: ${avoidPercentages[1]}%"></div>`;

    try {
      this.webController.loadData(padTop + content + padBottom, 'text/html', 'UTF-8', 'file://' + this.context.filesDir + '/meow/', ' ');
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
        this.loadWeb(resultText);
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
    return (this.myMeowLayout.wideMode ? 60 : 110);
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

  // Events

  @Monitor('meowDictExampleMDX.header')
  // Why warning O.o
  onDictRefresh() {
    console.log(`[Meow][MDX] Woof!`);
    this.firstPageLoaded = this.loadWeb(this.meowDictExampleBundle.mdx?.header?.toHtml());
  }

  @Monitor('myMeowFreeWindowModeStatus.on', 'myMeowAvoid.top', 'myMeowLayout.height', 'myMeowLayout.width', 'myMeowLayout.wideMode')
  refreshUIParams() {
    // console.log(`[Meow][web][refreshUIParams] !`);
    this.topDown = this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode;
    this.windowTopAvoid = this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : this.myMeowAvoid.top;
    this.linearBlurOps = this.constructLinearBlurOps();
  }

  @Monitor('myMeowAvoid.top')
  refreshWebToUpdateAvoid() {
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