import { deviceInfo } from '@kit.BasicServicesKit';
import { addUnitsToSize } from '../utils/data';

@ComponentV2
struct MeowFileInfo {
  @Param @Require filePath: string;
  @Param @Require fileSize: number;
  @Param deleteAction?: (() => void) | undefined = undefined;
  @Local name: string = 'file';
  @Local type: string = 'ext';

  @Monitor('filePath')
  aboutToAppear(): void {
    const spl = this.filePath.split('/');
    const name = spl[spl.length-1];
    const nameSpl = name.split('.');
    this.type = nameSpl[nameSpl.length-1].toUpperCase();
    this.name = name.substring(0, name.length - this.type.length - 1);
  }

  build() {
    Column({ space: 8 }) {
      Text(this.name)
        .fontSize(24)
      Text(addUnitsToSize(this.fileSize) + ' ' + this.type)
        .fontWeight(FontWeight.Bolder)
        .opacity(0.75)
      Text(this.filePath)
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
    .borderWidth(1)
    .borderColor($r('sys.color.comp_background_tertiary'))
    .backgroundEffect({ radius: 30, color: $r('app.color.blur_background') })
    .padding(10)
  }
}

export default MeowFileInfo