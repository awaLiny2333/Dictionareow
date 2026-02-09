import { meowDict, meowDictType } from '../hosts/meowDict';
import { deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize, resource_to_string } from '../utils/data';

@ComponentV2
struct MeowDictInfo {
  @Param @Require dict: meowDict;
  @Param deleteAction?: (() => void) | undefined = undefined;
  context: Context = this.getUIContext().getHostContext()!;

  build() {
    Column({ space: 8 }) {
      Text(this.dict.header?.Title)
        .fontWeight(FontWeight.Bold)
        .fontSize(24)
        .opacity(0.9)
        // .fontColor(this.dict.type == meowDictType.MDX ? $r('app.color.meow_onSub') : undefined)

      Text(`${this.dict.keyword?.numEntries} ${resource_to_string($r('app.string.entries'), this.context)}`)
        .fontWeight(FontWeight.Bolder)
        .opacity(0.75)
        // .fontColor(this.dict.type == meowDictType.MDX ? $r('app.color.meow_onSub') : undefined)

      Text(`${this.dict.header?.Encoding || 'Unknown encoding'}`)
        .fontWeight(FontWeight.Bolder)
        .opacity(0.75)
        // .fontColor(this.dict.type == meowDictType.MDX ? $r('app.color.meow_onSub') : undefined)

      Text(this.dict.fullPath)
        .opacity(0.5)
        // .fontColor(this.dict.type == meowDictType.MDX ? $r('app.color.meow_onSub') : undefined)

      Text(addUnitsToSize(this.dict.size) + ' ' + (this.dict.type == meowDictType.MDX ? 'MDX' : 'MDD'))
      // .fontWeight(FontWeight.Bolder)
        .opacity(0.5)
        // .fontColor(this.dict.type == meowDictType.MDX ? $r('app.color.meow_onSub') : undefined)

      if (this.deleteAction) {
        Row() {
          Button(` 󰀁 ${resource_to_string($r('app.string.delete'), this.context)}`)
            .onClick(() => {
              if (this.deleteAction) {
                this.deleteAction();
              }
            })
            // .backgroundColor(this.dict.type == meowDictType.MDX ? $r('app.color.blur_background') : $r('app.color.meow_brand'))
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
    .backgroundEffect({ radius: 30, color: this.dict.type == meowDictType.MDX ? $r('app.color.meow_iconSubEmphasize') : $r('app.color.blur_background') })
    .padding(10)
  }
}

export default MeowDictInfo