import { deviceInfo } from '@kit.BasicServicesKit';

@ComponentV2
struct MeowHistoryEntry {
  @Param keyword: string = 'Keyword';
  // @Param info: string = 'Info';
  @Param clickAction?: (() => void) | undefined = undefined;

  build() {
    // Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(5) } }) {
    Text(this.keyword)
      .fontWeight(FontWeight.Bold)
      .fontSize(16)
      // Text(this.info)
      //   .opacity(0.75)
      //   .maxLines(1)
      //   .textOverflow({ overflow: TextOverflow.Ellipsis })
      // }
      .borderRadius(deviceInfo.deviceType == deviceInfo.DeviceTypes.TYPE_2IN1 ? 8 : 20)
      .padding(8)
      .hoverEffect(HoverEffect.Highlight)
      .onClick(() => {
        if (this.clickAction) {
          this.clickAction();
        }
      })
  }
}

export default MeowHistoryEntry;