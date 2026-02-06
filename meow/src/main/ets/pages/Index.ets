import { meowDict, meowDictType } from '../hosts/meowDict';
import { fileDocumentPick2ArrayBuffer, sandboxCreateDir, sandboxSaveSync } from '../utils/storage';
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { defaultAnima, defaultDecorHeight, meowAvoid, meowFreeWindowModeStatus, meowLayoutModeStatus, meowVp2px } from '../utils/uiEnv';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { keepOnlyAlphanumericGlobal } from '../utils/data';
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { meowTheme } from '../hosts/meowTheme';

@Entry
@ComponentV2
struct Index {
  @Local myMeowAvoid: meowAvoid = AppStorageV2.connect<meowAvoid>(meowAvoid)!;
  @Local myMeowFreeWindowModeStatus: meowFreeWindowModeStatus = AppStorageV2.connect<meowFreeWindowModeStatus>(meowFreeWindowModeStatus)!;
  @Local myMeowLayout: meowLayoutModeStatus = AppStorageV2.connect<meowLayoutModeStatus>(meowLayoutModeStatus)!;
  @Local technicallyTopAvoid: number = this.onFreeWindowOrAvoidRefresh();
  // Data
  @Local meowDictExampleMDX: meowDict = AppStorageV2.connect<meowDict>(meowDict, 'meowDictExampleMDX', () => new meowDict(meowDictType.MDX))!;
  @Local meowDictExampleMDD: meowDict = AppStorageV2.connect<meowDict>(meowDict, 'meowDictExampleMDD', () => new meowDict(meowDictType.MDD))!;
  // Runtime interaction
  @Local lookUpWordMDX: string = '';
  @Local lookUpResult: boolean = true;
  @Local keywordsInSameIndexBlock: string[] = [];
  @Local keywordsInSameIndexBlockRelative: string[] = [];
  refreshForResourcesTimeout: number | undefined;
  // Runtime UI
  @Local render: boolean = false;
  @Local firstPageLoaded: boolean = false;
  @Local mainColor: string = '#00000000';
  @Local isMainColorTransparent: boolean = true;
  @Local linearBlurOps: LinearGradientBlurOptions = {
    fractionStops: [
      [1, 0],
      // [0.8, this.technicallyTopAvoid / this.myMeowLayout.height],
      [0, (this.technicallyTopAvoid + this.titleHeight()) / this.myMeowLayout.height]
    ],
    direction: GradientDirection.Bottom
  };
  // Runtime Objects
  webController: WebviewController = new webview.WebviewController();

  build() {
    WithTheme({ theme: new meowTheme() }) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.render) {
          Scroll() {
            Column() {
              Row()
                .height(this.titleHeight() + this.myMeowAvoid.top + 10 + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0))
                .animation(defaultAnima)

              Web({ controller: this.webController, src: '', renderMode: RenderMode.SYNC_RENDER })
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
                .layoutMode(WebLayoutMode.FIT_CONTENT) // 设置为Web组件大小自适应页面内容
                .overScrollMode(OverScrollMode.NEVER) // 设置过滚动模式为关闭状态
                .onControllerAttached(() => {
                  if (!this.firstPageLoaded) {
                    console.log(`[Meow][MDX] Woof! From onControllerAttached!`);
                    this.firstPageLoaded = true;
                    this.loadWeb(this.meowDictExampleMDX.header?.toHtml());
                  }
                })
                .borderRadius(15)
                // .backgroundColor(Color.Transparent)
                .onPageEnd(() => {
                  setTimeout(() => {
                    this.extractWebColor();
                  }, 500)
                })
                .margin(this.myMeowFreeWindowModeStatus.on ? {} : { left: this.myMeowAvoid.left, right: this.myMeowAvoid.right })
                .id('mainWeb')

              Row()
                .height(this.myMeowAvoid.bottom)
                .animation(defaultAnima)

            }
          }
          .padding({ left: 10, right: 10 })
          .linearGradientBlur(100, this.linearBlurOps)
          .id('mainWebFrame')

          RelativeContainer() {
            Row({ space: 10 }) {
              Button(this.meowDictExampleMDX?.header ? 'MDX  󰀓' : '󰀵 MDX')
                .onClick(() => {
                  fileDocumentPick2ArrayBuffer(['.mdx']).then((r) => {
                    if (r.succeed) {
                      this.meowDictExampleMDX = new meowDict(meowDictType.MDX, r.buf!);
                      sandboxCreateDir('meow', this.getUIContext().getHostContext()!, true).then(() => {
                        sandboxSaveSync('woof/woof.mdx', r.buf!, this.getUIContext().getHostContext()!, true);
                      })
                    }
                  })
                })
              Button(this.meowDictExampleMDD?.header ? 'MDD  󰀓' : '󰀵 MDD')
                .onClick(() => {
                  fileDocumentPick2ArrayBuffer(['.mdd']).then((r) => {
                    if (r.succeed) {
                      this.meowDictExampleMDD = new meowDict(meowDictType.MDD, r.buf!);
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
            .animation(defaultAnima)

            Row({ space: 10 }) {
              TextInput({ placeholder: `󰀩 ${this.meowDictExampleMDX.header?.Title || ''}`, text: this.lookUpWordMDX })
                .layoutWeight(1)
                .onChange((e) => {
                  this.lookUpWordMDX = e;
                })
                .onSubmit(() => {
                  clearTimeout(this.refreshForResourcesTimeout);
                  this.search(this.meowDictExampleMDX, this.lookUpWordMDX).then((result) => {
                    this.lookUpResult = result;
                  })
                })
                .selectAll(true)
                .selectedBackgroundColor($r('sys.color.font'))

              Button(`${this.lookUpResult ? '' : '¯\\_(ツ)_/¯  '}󰈱`)
                .onClick(() => {
                  clearTimeout(this.refreshForResourcesTimeout);
                  this.search(this.meowDictExampleMDX, this.lookUpWordMDX).then((result) => {
                    this.lookUpResult = result;
                  })
                })
            } // Search bar
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
          .backgroundEffect({ radius: 60, color: $r('app.color.blur_background') })
          .padding(10)
          .margin({
            left: 10,
            bottom: this.myMeowAvoid.bottom,
            right: 10,
            top: this.myMeowAvoid.top + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0)
          })
          .shadow(ShadowStyle.OUTER_DEFAULT_LG)

          Text(this.meowDictExampleMDX?.header?.Title)
            .padding(10)
            .width('100%')
            .textAlign(TextAlign.Center)
            .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.isMainColorTransparent && this.myMeowFreeWindowModeStatus.on ? undefined : this.mainColor)
      .animation(defaultAnima)
      .onAreaChange((o, n) => {
        if (o.width != n.width) {
          this.myMeowLayout.width = n.width as number;
          this.myMeowLayout.wideMode = this.myMeowLayout.width > 800;
        }
        if (o.height != n.height) {
          this.myMeowLayout.height = n.height as number;
        }
      })
      .onAppear(() => {
        this.render = true;
      })
    }
  }

  // Actions

  loadWeb(content: string | undefined) {
    if (!content) {
      return false;
    }

    // Not elegant
    // let pad = `<div style="height: ${(this.myMeowLayout.wideMode ? 50 : 130) + 20}px"></div>`;

    try {
      this.webController.loadData(content, 'text/html', 'UTF-8', 'file://' + this.getUIContext().getHostContext()!.filesDir + '/meow/', ' ');
      console.log(content);
      return true;
    } catch (e) {
      console.error(`[Meow] loadWeb() Failed! ${e}`);
      return false;
    }
  }

  async search(dict: meowDict | undefined, key: string) {
    if (!dict || !dict.isReady()) {
      return false;
    }

    const query = keepOnlyAlphanumericGlobal(key.toLowerCase());
    return dict.lookUpKey(query, true).then((resultBuffer) => {
      if (!resultBuffer) {
        // Not found
        return false;
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

      return true;
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

  extractWebColor() {
    this.getUIContext().getComponentSnapshot().get('mainWeb', (e, pixmap: image.PixelMap) => {
      if (e) {
        console.error(`[Meow][extractWebColor][Web] error: ${e}`);

        // Retry from frame
        this.getUIContext().getComponentSnapshot().get('mainWebFrame', (e, pixmap: image.PixelMap) => {
          if (e) {
            console.error(`[Meow][Frame][extractWebColor] error: ${e}`);
            return;
          }
          console.log(`[Meow][extractWebColor][Frame] extractWebColor from frame!`);
          this.pickerGetColor(pixmap);
        }, {
          waitUntilRenderFinished: true,
          region: {
            left: meowVp2px(10),
            right: meowVp2px(this.myMeowLayout.width - 10),
            top: meowVp2px(this.titleHeight() + this.myMeowAvoid.top + 20 + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0)),
            bottom: meowVp2px(this.myMeowLayout.height - this.myMeowAvoid.bottom - 10)
          }
        });

        return;

      } else {
        console.log(`[Meow][extractWebColor][Web] extractWebColor from web!`);
        this.pickerGetColor(pixmap);
      }
    }, {
      waitUntilRenderFinished: true,
    });
  }

  pickerGetColor(pixelMap: image.PixelMap) {
    effectKit.createColorPicker(pixelMap)
      .then(colorPicker => {
        colorPicker.getMainColor().then((mainColor) => {
          let a = mainColor.alpha.toString(16);

          let r = mainColor.red.toString(16);
          let g = mainColor.green.toString(16);
          let b = mainColor.blue.toString(16);

          if (a == '0') {
            a = '00';
          }
          if (r == '0') {
            r = '00';
          }
          if (g == '0') {
            g = '00';
          }
          if (b == '0') {
            b = '00';
          }

          let hexColor = `#${a}${r}${g}${b}`;
          console.log(`[Meow][extractWebColor] Extracted Color: ${hexColor}`);
          this.mainColor = hexColor;

          this.isMainColorTransparent = mainColor.alpha == 0;
        })
      })
      .catch((reason: BusinessError) => {
        console.error("[Meow][extractWebColor] effectKit.createColorPicker(pixmap) error = " + reason.message);
      })
  }

  // Data

  titleHeight() {
    return (this.myMeowLayout.wideMode ? 60 : 110);
  }

  // Events

  @Monitor('meowDictExampleMDX.header')
  // Why warning O.o
  onDictRefresh() {
    console.log(`[Meow][MDX] Woof!`);
    this.firstPageLoaded = this.loadWeb(this.meowDictExampleMDX.header?.toHtml());
  }

  @Monitor('myMeowFreeWindowModeStatus.on', 'myMeowAvoid.top', 'myMeowLayout.height')
  onFreeWindowOrAvoidRefresh() {
    if (this.myMeowFreeWindowModeStatus.on) {
      this.technicallyTopAvoid = defaultDecorHeight;
    } else {
      this.technicallyTopAvoid = this.myMeowAvoid.top;
    }

    this.linearBlurOps = {
      fractionStops: [
        [1, 0],
        [0.8, this.technicallyTopAvoid / this.myMeowLayout.height],
        [0, (this.technicallyTopAvoid + this.titleHeight()) / this.myMeowLayout.height]
      ],
      direction: GradientDirection.Bottom
    };

    return this.technicallyTopAvoid;
  }
}