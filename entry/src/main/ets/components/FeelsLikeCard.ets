/**
 * 体感温度卡片
 * 展示体感温度及与实际温度的对比
 */
@Component
export struct FeelsLikeCard {
  @Prop feelsLike: string = ''
  @Prop currentTemp: string = ''
  @Prop isClearBg: boolean = false
  @StorageProp('tempUnit') tempUnit: string = '°C'
  onCardClick?: () => void

  private getComparisonText(): string {
    const fl = parseFloat(this.feelsLike)
    const ct = parseFloat(this.currentTemp)
    if (isNaN(fl) || isNaN(ct)) return ''
    const diff = fl - ct
    if (Math.abs(diff) < 1) return '体感与实际相近'
    return diff > 0 ? '体感温度更高' : '体感温度更低'
  }

  private getComparisonColor(): string {
    const fl = parseFloat(this.feelsLike)
    const ct = parseFloat(this.currentTemp)
    if (isNaN(fl) || isNaN(ct)) return 'rgba(255,255,255,0.25)'
    const diff = fl - ct
    if (Math.abs(diff) < 1) return '#ffffff'
    return diff > 0 ? '#FF9500' : '#5AC8FA'
  }

  build() {
    Row() {
      Column() {
        Text('体感温度')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.60)')
          .margin({ bottom: 4 })

        Row({ space: 4 }) {
          Text(this.feelsLike || '--')
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getComparisonColor())

          Text(this.tempUnit)
            .fontSize(16)
            .fontColor(this.getComparisonColor())
            .fontWeight(FontWeight.Medium)
        }

        Text(this.getComparisonText())
          .fontSize(14)
          .fontColor(this.getComparisonColor())
          .fontWeight(FontWeight.Medium)
          .margin({ top: 2 })

        Row({ space: 4 }) {
          Text(`实际温度 ${this.currentTemp || '--'}°`)
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.50)')
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.35)' : 'rgba(0,0,0,0.30)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { if (this.onCardClick) this.onCardClick() })
  }
}
