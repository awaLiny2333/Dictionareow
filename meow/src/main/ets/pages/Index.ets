import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { AppStorageV2, LengthMetrics } from '@kit.ArkUI';
import { defaultAnima, defaultDecorHeight, meowAvoid, meowFreeWindowModeStatus, meowLayoutModeStatus } from '../utils/ui';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize, division, filterAtSimple, mimeOfFileName, resource2String } from '../utils/data';
import { meowTheme } from '../hosts/meowTheme';
import lazy { playThisForMe } from '../utils/av';
import lazy { fastbuffer } from '@kit.ArkTS';
import meowBundleInfo from '../components/MeowBundleInfo';
import { meowDictBundle } from '../hosts/meowDictBundle';
import { meowDictBundleLibrarian } from '../hosts/meowDictBundleLibrarian';
import { saveHybrid } from '../utils/storage';
import { meowMisc } from '../hosts/meowMisc';
import MeowHistoryEntry from '../components/MeowHistoryEntry';
import { meowHistory } from '../hosts/meowHistory';
import { common } from '@kit.AbilityKit';
import openLink from '../utils/jumps';
import { getPrivacyPolicyLink } from '../utils/privacy';

@Entry
@ComponentV2
struct Index {
  @Local myMeowAvoid: meowAvoid = AppStorageV2.connect<meowAvoid>(meowAvoid)!;
  @Local myMeowFreeWindowModeStatus: meowFreeWindowModeStatus = AppStorageV2.connect<meowFreeWindowModeStatus>(meowFreeWindowModeStatus)!;
  @Local myMeowLayout: meowLayoutModeStatus = AppStorageV2.connect<meowLayoutModeStatus>(meowLayoutModeStatus)!;
  @Local myMeowMisc: meowMisc = AppStorageV2.connect<meowMisc>(meowMisc, 'meowMisc', () => new meowMisc())!;
  @Local myMeowHistory: meowHistory = AppStorageV2.connect<meowHistory>(meowHistory, 'meowHistory', () => new meowHistory())!;
  @Local windowTopAvoid: number = 0;
  // Data
  @Local meowLibrarian: meowDictBundleLibrarian = AppStorageV2.connect<meowDictBundleLibrarian>(meowDictBundleLibrarian, 'meowDictBundleLibrarian', () => new meowDictBundleLibrarian())!;
  // Runtime interaction
  @Local lookUpWord: string = '';
  @Local keywordsInSameIndexBlock: string[] = [];
  @Local keywordsInSameIndexBlockRelevant: string[] = [];
  // Dictionaries
  @Local currentDictNo: number = this.myMeowMisc.defaultDictBundleIndex;
  @Local currentDictBundleTitle: string = '(～o￣3￣)～';
  @Local currentDictHasStats: boolean[] | undefined = undefined;
  // Runtime UI
  @Local topDown: boolean = this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode;
  @Local render: boolean = false;
  @Local renderWeb: boolean = false;
  @Local renderMore: boolean = false;
  @Local linearBlurOps: LinearGradientBlurOptions = this.constructLinearBlurOps();
  @Local isShowingInfo: boolean = false;
  @Local isShowingHistory: boolean = false;
  @Local buttonsWidth: number = 0;
  @Local buttonsHeight: number = 0;
  @Local buttonsExpanded: boolean = false;
  buttonsPanY: number = 0;
  timeoutIdForAvoidReload: number | undefined;
  // Runtime Objects
  webController: WebviewController = new webview.WebviewController();
  context: Context = this.getUIContext().getHostContext()!;

  aboutToAppear(): void {
    console.warn(`[UI][aboutToAppear] TopDown: ${this.topDown}`);
  }

  build() {
    WithTheme({ theme: new meowTheme() }) {
      Stack({ alignContent: Alignment.TopStart }) {
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
              .metaViewport(true)
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
                  this.lookUpKey(this.meowLibrarian.bundles[this.currentDictNo], decodeURIComponent(reqFileName));
                }

                return null;
              })
              // .borderRadius(15)
              .backgroundColor(Color.Transparent)
              .id('mainWeb')
              .linearGradientBlur(30, this.linearBlurOps)
          }

          Column({ space: 8 }) {
            if (this.renderMore) {
              Scroll() {
                Row({ space: 8 }) {
                  Button(`󰀵 ${resource2String($r('app.string.new_dictionary'), this.context)}`)
                    .onClick(() => {
                      this.meowLibrarian.createBundle(this.context);
                    })

                  Select(this.meowLibrarian.constructSelectOptions())
                    .selected(this.myMeowMisc.defaultDictBundleIndex)
                    .value(this.meowLibrarian.bundles[this.myMeowMisc.defaultDictBundleIndex]?.mdx?.header?.Title)
                    .onSelect((index: number) => {
                      console.info('[Meow][Select] Select:' + index);
                      this.myMeowMisc.defaultDictBundleIndex = index;
                      saveHybrid(this.context.filesDir + '/oops/default.txt', index.toString(), true);
                    })
                    .selectedOptionBgColor($r('app.color.meow_iconSubEmphasize'))
                    .selectedOptionFontColor($r('sys.color.font'))
                    .selectedOptionFont({ weight: FontWeight.Bold })

                  Button(`󰓞 ${resource2String($r('app.string.privacy_link'), this.context)}`)
                    .backgroundColor($r('app.color.meow_brand'))
                    .onClick(() => {
                      const link = getPrivacyPolicyLink('1889247809668921664'); // This may change if privacy policy in AGC changes
                      if (link) {
                        openLink(link, this.context as common.UIAbilityContext);
                      }
                    })
                }
              }
              .edgeEffect(EdgeEffect.Spring)
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .clip(true)
              .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)

              Scroll() {
                Column({ space: 8 }) {
                  ForEach(this.meowLibrarian.bundles, (bundle: meowDictBundle, idx: number) => {
                    meowBundleInfo({
                      bundle: bundle,
                      deleteAction: () => {
                        this.meowLibrarian.deleteBundle(idx, this.context);
                        if (idx == this.myMeowMisc.defaultDictBundleIndex) {
                          this.myMeowMisc.defaultDictBundleIndex = 0;
                        }
                      }
                    })
                  }, (bundle: meowDictBundle) => {
                    return bundle.sandboxPathWithEndSlash;
                  })
                }
              }
              .constraintSize({ maxHeight: this.myMeowLayout.height - this.windowTopAvoid - this.myMeowAvoid.bottom - this.titleHeight() - 91 })
              .width('100%')
              .align(Alignment.Top)
              .scrollable(ScrollDirection.Vertical)
              .edgeEffect(EdgeEffect.Spring)
              .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
            }
          } // More panel
          .visibility(this.isShowingInfo ? Visibility.Visible : Visibility.None)
          .animation(defaultAnima)
          .clip(true)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 15 : 30)
          .borderWidth(1)
          .borderColor($r('sys.color.icon_fourth'))
          .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
          .padding(10)
          .margin({
            left: 10,
            bottom: this.topDown ? 10 : this.myMeowAvoid.bottom + this.titleHeight() + 10,
            right: 10,
            top: this.topDown ? this.myMeowAvoid.top + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0) + this.titleHeight() + 10 : this.windowTopAvoid + 10
          })
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)

          Column() {
            Text(`(${this.myMeowHistory.data.length}/${this.myMeowHistory.limit})`)
              .opacity(0.75)
              .padding(8)
            Scroll() {
              Column() {
                ForEach(this.myMeowHistory.data, ((tempHisKey: string, idx: number) => {
                  MeowHistoryEntry({
                    keyword: this.myMeowHistory.data[idx],
                    clickAction: () => {
                      // Load
                      this.currentDictNo = this.myMeowMisc.defaultDictBundleIndex;
                      this.lookUpKey(this.meowLibrarian.bundles[this.myMeowMisc.defaultDictBundleIndex], tempHisKey);
                    },
                    contextMenuAction: () => {
                      this.myMeowHistory.deleteHistory(idx);
                    }
                  })
                }))
              }
              .alignItems(this.topDown ? HorizontalAlign.Start : HorizontalAlign.End)
            }
            .padding({ right: 6 })
            .constraintSize({ maxHeight: this.myMeowLayout.height - this.windowTopAvoid - this.myMeowAvoid.bottom - this.titleHeight() - 75 })
            .scrollable(ScrollDirection.Vertical)
            .edgeEffect(EdgeEffect.Spring)

            if (this.myMeowHistory.data.length == 0) {
              Text('¯\\_(ツ)_/¯')
            }
          } // History panel
          .visibility(this.isShowingHistory ? Visibility.Visible : Visibility.None)
          .animation(defaultAnima)
          .clip(true)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 15 : 30)
          .borderWidth(1)
          .borderColor($r('sys.color.icon_fourth'))
          .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
          .padding({
            top: 10,
            left: 10,
            bottom: 10,
            right: 4
          })
          .margin({
            left: 10,
            bottom: this.topDown ? 10 : this.myMeowAvoid.bottom + this.titleHeight() + 10,
            right: 10,
            top: this.topDown ? this.myMeowAvoid.top + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0) + this.titleHeight() + 10 : this.windowTopAvoid + 10
          })
          .constraintSize({ maxWidth: Math.max(400, this.myMeowLayout.width * 0.4) })
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)

          RelativeContainer() {
            if (this.render) {
              Row() {
                Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {

                  Button(`󰊖 ${resource2String($r('app.string.info'), this.context)}`)
                    .onClick(() => {
                      this.isShowingHistory = false;
                      this.isShowingInfo = !this.isShowingInfo;
                      this.renderMore = true;
                    })
                    .border(this.isShowingInfo ? { width: 2, color: $r('app.color.button_border') } : { width: 2, color: Color.Transparent })
                    .brightness(this.isShowingInfo ? 1.1 : 1)
                    .animation(defaultAnima)

                  Button(`󰏕 ${resource2String($r('app.string.history'), this.context)}`)
                    .onClick(() => {
                      // console.log('[History][tempHistory]\n' + this.tempHistory);
                      // console.log('[History][tempBase]\n' + this.tempBase);
                      this.isShowingInfo = false;
                      this.isShowingHistory = !this.isShowingHistory;
                    })
                    .border(this.isShowingHistory ? { width: 2, color: $r('app.color.button_border') } : { width: 2, color: Color.Transparent })
                    .brightness(this.isShowingHistory ? 1.1 : 1)
                    .animation(defaultAnima)

                  // Default

                  Button(`󰀲 ${this.meowLibrarian.bundles[this.myMeowMisc.defaultDictBundleIndex]?.mdx?.header?.Title || ''}`)
                    .onClick(() => {
                      this.currentDictNo = this.myMeowMisc.defaultDictBundleIndex;
                      this.lookUpKey(this.meowLibrarian.bundles[this.myMeowMisc.defaultDictBundleIndex], this.lookUpWord);
                    })
                    .opacity(this.currentDictHasStats ? (this.currentDictHasStats[this.myMeowMisc.defaultDictBundleIndex] ? 1 : 0.5) : 0.5)
                    .border(this.currentDictNo == this.myMeowMisc.defaultDictBundleIndex ? { width: 2, color: $r('app.color.button_border') } : { width: 2, color: Color.Transparent })
                    .brightness(this.currentDictNo == this.myMeowMisc.defaultDictBundleIndex ? 1.1 : 1)
                    .animation(defaultAnima)

                  // Others

                  ForEach(this.meowLibrarian.bundles, (bundle: meowDictBundle, index: number) => {
                    if (index != this.myMeowMisc.defaultDictBundleIndex) {
                      Button(`${bundle.mdx?.header?.Title}`)
                        .onClick(() => {
                          this.currentDictNo = index;
                          this.lookUpKey(bundle, this.lookUpWord);
                        })
                        .opacity(this.currentDictHasStats ? (this.currentDictHasStats[index] ? 1 : 0.5) : 0.5)
                        .border(this.currentDictNo == index ? { width: 2, color: $r('app.color.button_border') } : { width: 2, color: Color.Transparent })
                        .brightness(this.currentDictNo == index ? 1.1 : 1)
                        .animation(defaultAnima)
                    }
                  }, (bundle: meowDictBundle) => {
                    return bundle.sandboxPathWithEndSlash;
                  })
                }
                .animation(defaultAnima)
                .onAreaChange((o, n) => {
                  if (o.width != n.width) {
                    this.buttonsWidth = n.width as number;
                  }
                  if (o.height != n.height) {
                    this.buttonsHeight = n.height as number;
                  }
                })
              }
              .constraintSize(this.buttonsExpanded ? {} : { maxHeight: 40 })
              .animation(defaultAnima)
              .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
              .alignItems(VerticalAlign.Top)
              .clip(true)
              .alignRules({ left: { anchor: '__container__', align: HorizontalAlign.Start }, top: { anchor: '__container__', align: VerticalAlign.Top } })
              .id('fileControlButtons')
            }

            Row({ space: 10 }) {
              if (this.needExpandable()) {
                Button(this.buttonsExpanded ? (this.topDown ? '󰃘' : '󰃛') : (!this.topDown ? '󰃘' : '󰃛'))
                  .onClick(() => {
                    this.buttonsExpanded = !this.buttonsExpanded;
                  })
              }

              TextInput({ placeholder: `󰀩 ${this.currentDictBundleTitle}`, text: this.lookUpWord })
                .layoutWeight(1)
                .onChange((e) => {
                  this.lookUpWord = e;
                })
                .onSubmit(() => {
                  // this.currentDictNo = this.myMeowMisc.defaultDictBundleIndex;
                  this.lookUpKey(this.meowLibrarian.bundles[this.currentDictNo], this.lookUpWord);
                  if (this.myMeowFreeWindowModeStatus.on) {
                    setTimeout(() => {
                      focusControl.requestFocus('searchInput');
                    }, 10)
                  }
                })
                .selectAll(true)
                .selectedBackgroundColor($r('app.color.meow_iconSubEmphasize'))
                .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
                .keyboardShortcut('F', [ModifierKey.CTRL])
                .id('searchInput')
                .onAppear(() => {
                  setTimeout(() => {
                    focusControl.requestFocus('searchInput');
                  }, 10)
                })

              Button(`󰈱`)
                .onClick(() => {
                  // this.currentDictNo = this.myMeowMisc.defaultDictBundleIndex;
                  this.lookUpKey(this.meowLibrarian.bundles[this.currentDictNo], this.lookUpWord);
                })
            } // Search bar
            .id('searchBar')
            .alignRules({
              left: { anchor: '__container__', align: HorizontalAlign.Start },
              right: { anchor: '__container__', align: HorizontalAlign.End },
              bottom: { anchor: '__container__', align: VerticalAlign.Bottom }
            })
            .animation(defaultAnima)

          } // Title
          .height(this.titleHeight())
          .animation(defaultAnima)
          .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 15 : 30)
          .borderWidth(1)
          .borderColor($r('sys.color.icon_fourth'))
          .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
          .padding(10)
          .margin({
            left: 10,
            bottom: this.myMeowAvoid.bottom,
            right: 10,
            top: this.myMeowAvoid.top + (this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : 0)
          })
          .shadow(ShadowStyle.OUTER_DEFAULT_SM)
          .gesture(
            PanGesture({ direction: PanDirection.Up | PanDirection.Down })
              .onActionStart(() => {
                console.info('Pan start');
                this.buttonsPanY = 0;
              })
              .onActionUpdate((e: GestureEvent) => {
                this.buttonsPanY += e.offsetY;
              })
              .onActionEnd(() => {
                if (this.topDown) {
                  this.buttonsExpanded = this.buttonsPanY > 0;
                } else {
                  this.buttonsExpanded = this.buttonsPanY < 0;
                }
              })
          )

          // if (this.myMeowMisc.debugOutput) {
          //   TextArea({ text: this.myMeowMisc.debugOutput })
          // }
        }
        .height('100%')
        .width('100%')
        .alignContent(this.topDown ? Alignment.TopStart : Alignment.BottomEnd)
        .animation(defaultAnima)


        if (this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode) {
          Text(this.currentDictBundleTitle)
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

    const head = '<head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>';

    const avoidPercentages = this.constructWebAvoidPercentages();
    const padTop = `<div id='dictionareowTopAvoid' style="height: ${avoidPercentages[0]}%"></div>`;
    const padBottom = `<div id='dictionareowBottomAvoid' style="height: ${avoidPercentages[1]}%"></div>`;

    console.log(`[Meow][loadWeb] base is ${'file://' + base}`);

    try {
      // this.currentBase = base + 'meow/';
      this.webController.loadData(head + padTop + content + padBottom, 'text/html', 'UTF-8', 'file://' + base, ' ');
      // console.log(content);
      return true;
    } catch (e) {
      console.error(`[Meow] loadWeb() Failed! ${e}`);
      return false;
    }
  }

  async lookUpKey(bundle: meowDictBundle | undefined, key: string) {
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

    const query = key.toLowerCase();
    return bundle.lookUpKeyFromMDX(query)?.then(async (resultBuffers) => {
      if (!resultBuffers) {
        // Not found
        return false;
      }

      let resultTexts: string[] = [];

      for (let index = 0; index < resultBuffers.length; index++) {
        let resultText = 'ERROR! ＞︿＜';
        try {
          resultText = fastbuffer.from(resultBuffers[index]).toString(bundle.mdx!.header!.Encoding);
          // console.log(`[Meow][MDX] ${resultText}`);
          console.log(`[Meow][MDX][${key}] RAW resultText = ${resultText}`);

          // TODO: .includes is low performance!
          const knownKeys = []; // Believe in the dictionary builders and No duplicated keys will be needed to avoid.
          let layers = 0;
          while (resultText.includes('@@@LINK=') && layers < 10) {
            console.log(`
            [Meow][MDX][${key}] JUMP
            `);
            resultText = await this.fetchJumpsAsync(bundle, resultText, knownKeys);
            layers += 1;
          }

        } catch (e) {
          console.error(`[Meow][MDX][${key}] Error for resultText = resultBuffer.toString(dict.header!.Encoding);! ${e}`);
        }
        resultTexts.push(resultText);
        console.log(`[Meow][MDX][${key}] resultText = ${resultText}`);
      }

      const thisLoad = resultTexts.join(division(resource2String($r('app.string.link_to'), this.context)));
      const thisBase = this.currentBase();

      this.myMeowHistory.addHistory(key);

      this.loadWeb(thisLoad, thisBase);
      // console.log(`[Meow][MDX] Got result!`);

      return true;
    })
  }

  // TODO: Low performance!
  async fetchJumpsAsync(bundle: meowDictBundle, text: string, key: string[]) {
    let filterResult = filterAtSimple(text, key);
    text = filterResult[0];

    // Get all @@@LINK= out.
    let pieces = [text];

    for (let index = 1; index < filterResult.length; index++) {
      console.warn(`[Meow][MDX][filterAtSimple] ${filterResult.slice(1)}`);
      let resultBufferJump = await bundle.mdx?.jumpTo(filterResult[1]);
      if (!resultBufferJump) {
        // Not found
        continue;
      }

      try {
        const resultTextExtra = fastbuffer.from(resultBufferJump).toString(bundle.mdx!.header!.Encoding);
        pieces.push(resultTextExtra);
      } catch (e) {
        console.error(`[Meow][fetchJumpsAsync] Failed: ${e}`);
      }
    }

    text = pieces.join(division(resource2String($r('app.string.jump_to'), this.context)));
    return text;
  }

  // Data

  /**
   * Determines the title bar height.
   * @returns 60 or 110.
   * */
  titleHeight() {
    return 70 + (this.buttonsExpanded ? this.buttonsHeight : 40);
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
      bottomVp += this.titleHeight() + 10;
    }

    const topPercentage = topVp / this.myMeowLayout.height * 100;
    const bottomPercentage = bottomVp / this.myMeowLayout.height * 100;

    return [topPercentage, bottomPercentage];
  }

  currentBase() {
    return this.context.filesDir + '/' + this.meowLibrarian.bundles[this.currentDictNo]?.sandboxPathWithEndSlash + 'meow/';
  }

  needExpandable() {
    if (this.buttonsHeight > 41) {
      return true;
    }
    return false;
  }

  // Events

  @Monitor('myMeowFreeWindowModeStatus.onFocus')
  focusSearch() {
    if (this.myMeowFreeWindowModeStatus.onFocus) {
      if (this.myMeowFreeWindowModeStatus.on) {
        setTimeout(() => {
          focusControl.requestFocus('searchInput');
        }, 10)
      }
    }
  }

  @Monitor('lookUpWord')
  async refreshHasStats() {
    let uwu: boolean[] = [];
    for (let index = 0; index < this.meowLibrarian.bundles.length; index++) {
      let r = await this.meowLibrarian.bundles[index].hasKeyInMDX(this.lookUpWord)
      uwu.push(r);
    }
    this.currentDictHasStats = uwu;
  }

  @Monitor('currentDictNo', 'renderWeb')
  refreshBundleTitle() {
    this.currentDictBundleTitle = this.meowLibrarian.bundles[this.currentDictNo]?.mdx?.header?.Title || '';
  }

  @Monitor('myMeowFreeWindowModeStatus.on', 'myMeowAvoid.top', 'myMeowLayout.height', 'myMeowLayout.width', 'myMeowLayout.wideMode', 'buttonsWidth', 'buttonsHeight')
  refreshUIParams() {
    console.log(`[Meow][web][refreshUIParams] !`);
    this.topDown = this.myMeowFreeWindowModeStatus.on || this.myMeowLayout.wideMode;
    this.windowTopAvoid = this.myMeowFreeWindowModeStatus.on ? defaultDecorHeight : this.myMeowAvoid.top;
    this.linearBlurOps = this.constructLinearBlurOps();
  }

  @Monitor('myMeowFreeWindowModeStatus.on', 'myMeowAvoid.top', 'buttonsWidth', 'buttonsHeight', 'buttonsExpanded')
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

export const privacyPolicyLink: string = 'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1889247809668921664';