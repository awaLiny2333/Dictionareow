import { meowDict } from '../hosts/meowDict';
import { deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize, resource_to_string } from '../utils/data';
import { defaultAnima, meowLayoutModeStatus } from '../utils/ui';
import { AppStorageV2, LengthMetrics } from '@kit.ArkUI';
import MeowDictInfo from './MeowDictInfo';
import MeowFileInfo from './MeowFileInfo';
import { fileIo } from '@kit.CoreFileKit';
import { meowDictBundle } from '../hosts/meowDictBundle';
import { fileDocumentPick2Path } from '../utils/storage';

@ComponentV2
struct meowBundleInfo {
  @Param @Require bundle: meowDictBundle;
  @Local myMeowLayout: meowLayoutModeStatus = AppStorageV2.connect<meowLayoutModeStatus>(meowLayoutModeStatus)!;
  @Local isExpanded: boolean = false;
  @Local renderExpanded: boolean = false;
  @Param deleteAction?: (() => void) | undefined = undefined;
  context: Context = this.getUIContext().getHostContext()!;

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.bundle.mdx?.header?.Title || 'meow')
          .fontWeight(FontWeight.Bolder)
          .fontSize(20)
          .opacity(0.9)
          .layoutWeight(1)

        SymbolGlyph(this.isExpanded ? $r('sys.symbol.arrow_down_right_and_arrow_up_left') : $r('sys.symbol.square_and_pencil'))
          .fontColor([$r('sys.color.font')])
          .fontSize(26)
          .opacity(0.9)
      }
      // .padding({ right: 10 })
      .justifyContent(FlexAlign.Center)

      if (this.renderExpanded) {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(5), cross: LengthMetrics.vp(2) } }) {
          Text(`${this.bundle.mdx?.keyword?.numEntries} ${resource_to_string($r('app.string.entries'), this.context)} / ${addUnitsToSize(this.bundle.totalSize)}`)
            .fontWeight(FontWeight.Bolder)
            .opacity(0.75)

          Text(`${this.context.filesDir}/${this.bundle.sandboxPathWithEndSlash}`)
            .fontWeight(FontWeight.Medium)
            .opacity(0.5)
        }
        .visibility(this.isExpanded ? Visibility.Visible : Visibility.None)
        .animation(defaultAnima)

        Scroll() {
          Row({ space: 10 }) {
            Button(this.bundle.mdx?.header ? 'MDX  󰀓' : '󰀵 MDX')
              .onClick(() => {
                fileDocumentPick2Path(['.mdx'], 1).then((r) => {
                  if (r.succeed) {
                    this.bundle.addMDX(r.sourcePaths![0], this.context);
                  }
                })
              })
            Button(`󰀵 MDD (${this.bundle.mdds.length})`)
              .onClick(() => {
                fileDocumentPick2Path(['.mdd'], 233).then((r) => {
                  if (r.succeed) {
                    for (let index = 0; index < r.sourcePaths!.length; index++) {
                      this.bundle.addMDD(r.sourcePaths![index], this.context);
                    }
                  }
                })
              })
            Button(`󰀵 ${resource_to_string($r('app.string.add_files'), this.context)} (${this.bundle.files.length})`)
              .onClick(() => {
                fileDocumentPick2Path([], 233).then((r) => {
                  if (r.succeed) {
                    for (let index = 0; index < r.sourcePaths!.length; index++) {
                      this.bundle.addFile(r.sourcePaths![index], this.context, index == r.sourcePaths!.length - 1);
                    }
                  }
                })
              })

            if (this.deleteAction) {
              Button(` 󰀁 ${resource_to_string($r('app.string.delete'), this.context)}`)
                .onClick(() => {
                  if (this.deleteAction) {
                    this.deleteAction();
                  }
                })
            }
          } // Buttons
        } // Control buttons
        .visibility(this.isExpanded ? Visibility.Visible : Visibility.None)
        .animation(defaultAnima)
        .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        Column({ space: 8 }) {
          if (this.bundle.mdx) {
            MeowDictInfo({
              dict: this.bundle.mdx,
              deleteAction: () => {
                fileIo.unlink(this.bundle.mdx!.fullPath)
                  .catch((e: BusinessError) => {
                    console.error(`[Meow][Info] fileIo.unlink(this.bundle.mdds[index].fullPath) Failed: ${e}`);
                  });
                this.bundle.mdx = undefined;
                this.bundle.updateSizes();
              }
            })
          }
          ForEach(this.bundle.mdds, ((mdd: meowDict, index: number) => {
            MeowDictInfo({
              dict: mdd,
              deleteAction: () => {
                fileIo.unlink(this.bundle.mdds[index].fullPath)
                  .catch((e: BusinessError) => {
                    console.error(`[Meow][Info] fileIo.unlink(this.bundle.mdds[index].fullPath) Failed: ${e}`);
                  });
                this.bundle.mdds.splice(index, 1);
                this.bundle.updateSizes();
              }
            })
          }))
          ForEach(this.bundle.files, ((path: string, index: number) => {
            MeowFileInfo({
              filePath: path,
              fileSize: this.bundle.fileSizes[index],
              deleteAction: () => {
                fileIo.unlink(path)
                  .then(() => {
                    this.bundle.updateFilesSync(this.context);
                  })
                  .catch((e: BusinessError) => {
                    console.error(`[Meow][Info][Files] fileIo.unlink(path) Failed: ${e}`);
                  });
              }
            })
          }))
        } // Info
        .visibility(this.isExpanded ? Visibility.Visible : Visibility.None)
        .animation(defaultAnima)
        .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
      }

    }
    .hoverEffect(HoverEffect.Highlight)
    .onClick(() => {
      if (this.renderExpanded) {
        this.isExpanded = !this.isExpanded;
      } else {
        this.renderExpanded = true;
        setTimeout(() => {
          this.isExpanded = !this.isExpanded;
        }, 80)
      }
    })
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
    .borderWidth(1)
    .borderColor($r('sys.color.comp_background_tertiary'))
    .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
    .padding(10)
  }
}

export default meowBundleInfo;