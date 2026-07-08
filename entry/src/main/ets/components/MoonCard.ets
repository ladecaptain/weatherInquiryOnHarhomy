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
  @Prop nextFullMoon: string = ''
  @Prop isClearBg: boolean = false
  onCardClick?: () => void

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
            .margin({ bottom: 2 })

          Text(this.getMoonIllumination(this.moonPhaseIcon))
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.60)')

          if (this.nextFullMoon && this.nextFullMoon.length > 0) {
            Text(this.nextFullMoon)
              .fontSize(14)
              .fontColor('rgba(255,255,255,0.60)')
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 月出月落时间
        Column() {
          if (this.moonrise && this.moonrise.length > 0) {
            Row() {
              Text('月出')
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.55)')
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
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.55)')
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
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.35)' : 'rgba(0,0,0,0.30)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
    .onClick(() => { if (this.onCardClick) this.onCardClick() })
  }

  private getMoonEmoji(iconCode: string): string {
    if (iconCode === '800') return '🌑'
    if (iconCode === '801') return '🌒'
    if (iconCode === '802') return '🌓'
    if (iconCode === '803') return '🌔'
    if (iconCode === '804') return '🌕'
    if (iconCode === '805') return '🌖'
    if (iconCode === '806') return '🌗'
    if (iconCode === '807') return '🌘'
    return '🌙'
  }

  private getMoonIllumination(iconCode: string): string {
    if (iconCode === '800') return '0% 照射'
    if (iconCode === '801') return '~15% 照射'
    if (iconCode === '802') return '~50% 照射'
    if (iconCode === '803') return '~75% 照射'
    if (iconCode === '804') return '~100% 照射'
    if (iconCode === '805') return '~85% 照射'
    if (iconCode === '806') return '~50% 照射'
    if (iconCode === '807') return '~25% 照射'
    return ''
  }
}
