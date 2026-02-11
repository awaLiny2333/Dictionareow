import { meowDict, meowDictType } from '../hosts/meowDict';
import { deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize, resource_to_string } from '../utils/data';
import { LengthMetrics } from '@kit.ArkUI';

@ReusableV2
@ComponentV2
struct MeowDictInfo {
  @Param @Require dict: meowDict;
  @Param deleteAction?: (() => void) | undefined = undefined;
  context: Context = this.getUIContext().getHostContext()!;

  build() {
    Column({ space: 5 }) {
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(5), cross: LengthMetrics.vp(2) } }) {
        Text(this.dict.header?.Title)
          .fontWeight(FontWeight.Bold)
          .fontSize(16)
          .opacity(0.9)

        Text(`${this.dict.keyword?.numEntries} ${resource_to_string($r('app.string.entries'), this.context)} / ${this.dict.header?.Encoding || 'Unknown encoding'} / ${addUnitsToSize(this.dict.size)}`)
          .fontWeight(FontWeight.Medium)
          .opacity(0.75)

        Text(this.dict.fullPath)
          .opacity(0.5)
      }

      if (this.deleteAction) {
        Row() {
          Button(` 󰀁 ${resource_to_string($r('app.string.delete'), this.context)}`)
            .onClick(() => {
              if (this.deleteAction) {
                this.deleteAction();
              }
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
    .borderWidth(1)
    .borderColor($r('sys.color.comp_background_tertiary'))
    .backgroundColor(this.dict.type == meowDictType.MDX ? $r('app.color.meow_iconSubEmphasize') : $r('app.color.blur_background'))
    // .backgroundEffect({ radius: 30, color: this.dict.type == meowDictType.MDX ? $r('app.color.meow_iconSubEmphasize') : $r('app.color.blur_background') })
    .padding(10)
  }
}

export default MeowDictInfo