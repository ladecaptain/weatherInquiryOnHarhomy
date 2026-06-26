import { ForecastDay } from '../model/WeatherModel'
import { getDayLabel, getWeatherIconResource } from '../utils/WeatherUtils'

/**
 * 天气预报列表组件（竖向排列）
 * 每日一行：日期 + 图标 + 描述 → 最低温 → 温差指示条 → 最高温
 */
@Component
export struct ForecastList {
  @Prop forecastDays: ForecastDay[] = []
  @Prop title: string = '未来 7 天'

  build() {
    Column() {
      // 标题行
      Row() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.80)')
        Blank()
        Text(`${this.forecastDays.length}天`)
          .fontSize(11)
          .fontColor('rgba(255,255,255,0.30)')
      }
      .width('100%')
      .padding({ left: 4, right: 4, bottom: 10 })

      if (this.forecastDays.length === 0) {
        Text('暂无预报数据')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.35)')
          .padding({ top: 10, bottom: 10 })
      } else {
        ForEach(this.forecastDays, (day: ForecastDay, index: number) => {
          Column() {
            Row() {
              // 左侧：日期 + 图标 + 天气描述
              Row({ space: 12 }) {
                Text(getDayLabel(day.fxDate))
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('rgba(255,255,255,0.85)')
                  .width(42)

                Image(getWeatherIconResource(day.iconDay))
                  .width(28)
                  .height(28)

                Text(day.textDay)
                  .fontSize(13)
                  .fontColor('rgba(255,255,255,0.55)')
                  .maxLines(1)
              }
              .layoutWeight(1)

              // 右侧：最低温 → 温差指示条 → 最高温
              Row({ space: 10 }) {
                Text(`${day.tempMin}°`)
                  .fontSize(13)
                  .fontColor('#6db3f2')
                  .fontWeight(FontWeight.Medium)
                  .width(36)
                  .textAlign(TextAlign.End)

                // 温差指示条
                this.TempDiffBar(Number(day.tempMin), Number(day.tempMax))

                Text(`${day.tempMax}°`)
                  .fontSize(13)
                  .fontColor('#ff6b6b')
                  .fontWeight(FontWeight.Medium)
                  .width(36)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            if (index < this.forecastDays.length - 1) {
              Row()
                .width('100%')
                .height(0.5)
                .backgroundColor('rgba(255,255,255,0.05)')
                .margin({ top: 10, bottom: 10 })
            }
          }
          .width('100%')
          .padding({ left: 4, right: 4 })
        }, (_day: ForecastDay, index: number) => index.toString())
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(255,255,255,0.06)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
  }

  /**
   * 温差指示条
   * 橙色填充长度 = (当日温差 / 7天中最大温差) * 条长
   * 剩余部分为透明轮廓
   */
  @Builder
  TempDiffBar(minTemp: number, maxTemp: number) {
    Stack({ alignContent: Alignment.Start }) {
      // 底层：透明轮廓
      Row()
        .width('100%')
        .height('100%')
        .borderRadius(2)
        .border({ width: 0.5, color: 'rgba(255,255,255,0.12)' })

      // 上层：橙色填充
      Row()
        .width(`${this.getDiffBarWidth(minTemp, maxTemp)}%`)
        .height('100%')
        .backgroundColor('#ff9f43')
        .borderRadius(2)
    }
    .width(88)
    .height(4)
  }

  /**
   * 计算温差条宽度百分比
   * 以 15°C 为基准温差做归一化（若 7 天最大温差更大则取实际值）
   */
  private getDiffBarWidth(minTemp: number, maxTemp: number): number {
    const diff = maxTemp - minTemp
    if (diff <= 0) {
      return 8
    }
    const maxDiffAcrossDays = this.getMaxTempDiff()
    // 基准温差不低于 15°C，避免温差接近时条总是满的
    const baseline = Math.max(maxDiffAcrossDays, 15)
    const pct = (diff / baseline) * 100
    return Math.max(10, Math.min(100, pct))
  }

  /** 获取 7 天预报中的最大温差 */
  private getMaxTempDiff(): number {
    let maxDiff = 0
    for (const day of this.forecastDays) {
      const diff = Number(day.tempMax) - Number(day.tempMin)
      if (diff > maxDiff) {
        maxDiff = diff
      }
    }
    return maxDiff
  }
}
