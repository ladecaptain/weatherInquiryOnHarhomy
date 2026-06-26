/**
 * 日出日落卡片 — 纯文字，无图标
 */
@Component
export struct SunriseSetCard {
  @Prop sunrise: string = ''  // QWeather 直接返回 "HH:mm"
  @Prop sunset: string = ''

  build() {
    Row() {
      // 日出
      Column() {
        Text('日出')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.45)')
          .margin({ bottom: 6 })
        Text(this.sunrise || '--:--')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffd700')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      // 分隔
      Column()
        .width(1)
        .height(40)
        .backgroundColor('rgba(255,255,255,0.10)')

      // 日落
      Column() {
        Text('日落')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.45)')
          .margin({ bottom: 6 })
        Text(this.sunset || '--:--')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ff6b35')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(80)
    .alignItems(VerticalAlign.Center)
    .padding(14)
    .backgroundColor('rgba(255,255,255,0.06)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
  }
}
