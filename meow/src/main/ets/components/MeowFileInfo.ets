import { deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize, resource_to_string } from '../utils/data';
import { LengthMetrics } from '@kit.ArkUI';

@ComponentV2
struct MeowFileInfo {
  @Param @Require filePath: string;
  @Param @Require fileSize: number;
  @Param deleteAction?: (() => void) | undefined = undefined;
  @Local name: string = 'file';
  context: Context = this.getUIContext().getHostContext()!;

  @Monitor('filePath')
  aboutToAppear(): void {
    const spl = this.filePath.split('/');
    this.name = spl[spl.length-1];
  }

  build() {
    Column({ space: 5 }) {
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(5), cross: LengthMetrics.vp(2) } }) {
        Text(this.name)
          .fontSize(16)
          .opacity(0.75)

        Text(this.filePath)
          .opacity(0.5)

        Text(addUnitsToSize(this.fileSize))
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
            .opacity(0.8)
          // .backgroundColor($r('app.color.meow_iconSubEmphasize'))
          // .fontColor($r('app.color.meow_onSub'))

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
    .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
    .padding(10)
  }
}

export default MeowFileInfo