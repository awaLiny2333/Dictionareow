import { deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize, resource_to_string } from '../utils/data';

@ComponentV2
struct MeowFileInfo {
  @Param @Require filePath: string;
  @Param @Require fileSize: number;
  @Param deleteAction?: (() => void) | undefined = undefined;
  @Local name: string = 'file';
  @Local type: string = 'ext';
  context: Context = this.getUIContext().getHostContext()!;

  @Monitor('filePath')
  aboutToAppear(): void {
    const spl = this.filePath.split('/');
    this.name = spl[spl.length-1];
    const nameSpl = this.name.split('.');
    this.type = nameSpl[nameSpl.length-1].toUpperCase();
  }

  build() {
    Column({ space: 8 }) {
      Text(this.name)
        // .fontWeight(FontWeight.Medium)
        .fontSize(24)
        .opacity(0.75)

      Text(this.filePath)
        .opacity(0.5)
      Text(addUnitsToSize(this.fileSize) + ' ' + this.type)
      // .fontWeight(FontWeight.Bolder)
        .opacity(0.5)

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