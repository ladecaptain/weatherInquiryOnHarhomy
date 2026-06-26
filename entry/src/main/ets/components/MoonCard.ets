/**
 * 月相信息卡片
 * 含月相图标、名称、月出/月落时间、距下次满月天数
 */
@Component
export struct MoonCard {
  @Prop moonPhase: string = ''
  @Prop moonPhaseIcon: string = ''
  @Prop moonrise: string = ''
  @Prop moonset: string = ''
  @Prop nextFullMoon: string = '' // 预计算好的展示文字，如 "距满月 3天"

  build() {
    Column() {
      Row() {
        Text(this.getMoonEmoji(this.moonPhaseIcon))
          .fontSize(40)
          .margin({ right: 12 })

        Column() {
          Text(this.moonPhase || '未知')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#ffffff')
            .margin({ bottom: 4 })

          if (this.nextFullMoon && this.nextFullMoon.length > 0) {
            Text(this.nextFullMoon)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.45)')
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 月出月落时间
        Column() {
          if (this.moonrise && this.moonrise.length > 0) {
            Row() {
              Text('月出')
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.35)')
                .margin({ right: 4 })
              Text(this.moonrise)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('rgba(255,255,255,0.75)')
            }
            .margin({ bottom: 6 })
          }

          if (this.moonset && this.moonset.length > 0) {
            Row() {
              Text('月落')
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.35)')
                .margin({ right: 4 })
              Text(this.moonset)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('rgba(255,255,255,0.75)')
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(255,255,255,0.06)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
  }

  /** 月相 emoji 映射 */
  private getMoonEmoji(iconCode: string): string {
    if (iconCode === '800') return '🌑'  // 新月
    if (iconCode === '801') return '🌒'  // 蛾眉月
    if (iconCode === '802') return '🌓'  // 上弦月
    if (iconCode === '803') return '🌔'  // 盈凸月
    if (iconCode === '804') return '🌕'  // 满月
    if (iconCode === '805') return '🌖'  // 亏凸月
    if (iconCode === '806') return '🌗'  // 下弦月
    if (iconCode === '807') return '🌘'  // 残月
    return '🌙'
  }
}
