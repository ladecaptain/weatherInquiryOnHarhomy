import { formatTempWithUnit } from '../services/TemperatureService'

/**
 * 降水卡片组件
 * 展示当前降水概率、降水量，点击打开降水详情弹窗
 */
@Component
export struct PrecipCard {
  @Prop pop: string = ''
  @Prop precip: string = ''
  onCardClick?: () => void

  build() {
    Column() {
      // 标题行
      Row() {
        Text('降水')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.40)')
          .fontWeight(FontWeight.Medium)

        Blank()

        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(12)
          .height(12)
          .fillColor('rgba(255,255,255,0.35)')
      }
      .width('100%')
      .margin({ bottom: 10 })

      // 数据行：概率 + 降水量 并排
      Row({ space: 20 }) {
        // 降水概率
        Column() {
          Text('降水概率')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.35)')
            .margin({ bottom: 4 })

          Text(this.pop && this.pop.length > 0 ? `${this.pop}%` : '--')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPopColor(parseFloat(this.pop)))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 降水量
        Column() {
          Text('降水量')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.35)')
            .margin({ bottom: 4 })

          Text(this.precip && this.precip.length > 0 ? `${this.precip} mm` : '--')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPrecipColor(parseFloat(this.precip)))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(255,255,255,0.06)')
    .backdropBlur(20)
    .borderRadius(16)
    .onClick(() => { if (this.onCardClick) this.onCardClick() })
  }

  private getPopColor(pop: number): string {
    if (isNaN(pop)) return 'rgba(255,255,255,0.70)'
    if (pop >= 80) return '#0A84FF'
    if (pop >= 50) return '#9B59B6'
    return 'rgba(255,255,255,0.70)'
  }

  private getPrecipColor(precip: number): string {
    if (isNaN(precip)) return 'rgba(255,255,255,0.70)'
    if (precip >= 10) return '#0A84FF'
    if (precip >= 5) return '#9B59B6'
    if (precip > 0) return '#5AC8FA'
    return 'rgba(255,255,255,0.50)'
  }
}
