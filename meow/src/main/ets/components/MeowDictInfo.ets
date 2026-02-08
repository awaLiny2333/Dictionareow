import { meowDict, meowDictType } from '../hosts/meowDict';
import { deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize } from '../utils/data';

@ComponentV2
struct MeowDictInfo {
  @Param @Require dict: meowDict;
  @Param deleteAction?: (() => void) | undefined = undefined;

  build() {
    Column({ space: 8 }) {
      Text(this.dict.header?.Title)
        .fontSize(24)
      Text(addUnitsToSize(this.dict.size) + ' ' + (this.dict.type == meowDictType.MDX ? 'MDX' : 'MDD'))
        .fontWeight(FontWeight.Bolder)
        .opacity(0.75)
      Text(this.dict.fullPath)
        .opacity(0.5)
      if (this.deleteAction) {
        Row() {
          Button(' 󰀁 Delete')
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
    .borderWidth(2)
    .borderColor($r('sys.color.comp_background_tertiary'))
    .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
    .padding(10)
  }
}

export default MeowDictInfo