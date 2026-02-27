import { deviceInfo } from '@kit.BasicServicesKit';
import { resource2String } from '../utils/data';
import { defaultAnima } from '../utils/ui';

@ComponentV2
struct MeowHistoryEntry {
  @Param keyword: string = 'Keyword';
  @Param clickAction?: (() => void) | undefined = undefined;
  @Param contextMenuAction?: (() => void) | undefined = undefined;
  // Runtime data
  @Local isMenu: boolean = false;
  context: Context = this.getUIContext().getHostContext()!;

  build() {
    Text(` ${this.keyword} `)
      .fontWeight(this.isMenu ? FontWeight.Bolder : FontWeight.Medium)
      .brightness(this.isMenu ? 1.1 : 1)
      .animation(defaultAnima)
      .fontSize(16)
      .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
      .padding(8)
      .hoverEffect(HoverEffect.Highlight)
      .onClick(() => {
        if (this.clickAction) {
          this.clickAction();
        }
      })
      .gesture(
        LongPressGesture({ repeat: true })
          .onAction(() => {
            this.isMenu = true;
          })
      )
      .onMouse((e) => {
        if ((e.button == MouseButton.Right) && (e.action == MouseAction.Press)) {
          this.isMenu = true;
        }
      })
      .bindContextMenu(this.isMenu, this.bindMenuBuilder(), {
        onDisappear: () => {
          this.isMenu = false;
        },
        // hapticFeedbackMode: HapticFeedbackMode.ENABLED
      })
  }

  @Builder
  bindMenuBuilder() {
    Text(` 󰀁 ${resource2String($r('app.string.delete'), this.context)}`)
      .onClick(() => {
        if (this.contextMenuAction) {
          this.contextMenuAction();
        }
      })
      .padding(8)
      .hoverEffect(HoverEffect.Highlight)
      .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 5 : 18)
  }
}

export default MeowHistoryEntry;