/**
 * 日出日落详情弹窗
 * 当日日照时段可视化 + 7 天日出日落列表
 */
import { formatDate, getDayLabel } from '../utils/WeatherUtils'
import { ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface SunSlot {
  dateStr: string; label: string; monthDay: string
  sunrise: string; sunset: string
  daylightHours: string  // e.g. "12h 34m"
}

@CustomDialog
export struct SunriseDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload

  private getSunSlots(): SunSlot[] {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const all = this.payload.forecastDays
    const slots: SunSlot[] = []
    for (let i = 0; i < all.length && slots.length < 7; i++) {
      const d = new Date(today.getTime() + i * 86400000)
      const ds = formatDate(d)
      const fc = all[i]
      slots.push({
        dateStr: ds,
        label: getDayLabel(ds),
        monthDay: `${d.getMonth() + 1}/${d.getDate()}`,
        sunrise: fc.sunrise || '--',
        sunset: fc.sunset || '--',
        daylightHours: this.calcDaylight(fc.sunrise, fc.sunset)
      })
    }
    return slots
  }

  private calcDaylight(sunrise: string, sunset: string): string {
    if (!sunrise || !sunset) return '--'
    const sr = this.timeToMinutes(sunrise)
    const ss = this.timeToMinutes(sunset)
    if (sr < 0 || ss < 0) return '--'
    const diff = ss - sr
    if (diff <= 0) return '--'
    const h = Math.floor(diff / 60)
    const m = diff % 60
    return `${h}h ${m}m`
  }

  private timeToMinutes(t: string): number {
    const parts = t.split(':')
    if (parts.length < 2) return -1
    return parseInt(parts[0]) * 60 + parseInt(parts[1])
  }

  /** 日出/日落在 24h 条上的百分比位置 */
  private timeToPercent(t: string): number {
    const m = this.timeToMinutes(t)
    if (m < 0) return 0
    return Math.max(0, Math.min(100, (m / 1440) * 100))
  }

  build() {
    Column() {
      // 标题栏 + X 关闭按钮
      Row() {
        Text(`${this.payload.cityName} · 日出日落`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
        Blank()
        Button() { Image($r('sys.media.ohos_ic_public_close')).width(22).height(22).fillColor('#ffffff') }
          .width(38).height(38)
          .backgroundColor('rgba(255,255,255,0.10)')
          .borderRadius(19)
          .onClick(() => this.controller.close())
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 10, bottom: 16 })

      if (this.payload.forecastDays.length > 0) {
        // 今日日照可视化
        Column() {
          Row() {
            Column() {
              Text('日出').fontSize(12).fontColor('rgba(255,255,255,0.40)')
              Text(this.payload.forecastDays[0].sunrise || '--').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#ffd700')
            }.alignItems(HorizontalAlign.Center).layoutWeight(1)

            Column() {
              Text('日照时长').fontSize(12).fontColor('rgba(255,255,255,0.40)')
              Text(this.calcDaylight(this.payload.forecastDays[0].sunrise, this.payload.forecastDays[0].sunset))
                .fontSize(28).fontWeight(FontWeight.Bold).fontColor('#ffffff')
            }.alignItems(HorizontalAlign.Center).layoutWeight(1)

            Column() {
              Text('日落').fontSize(12).fontColor('rgba(255,255,255,0.40)')
              Text(this.payload.forecastDays[0].sunset || '--').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#ff6b35')
            }.alignItems(HorizontalAlign.Center).layoutWeight(1)
          }
          .width('100%')
          .margin({ bottom: 16 })

          // 24h 昼夜条
          Column() {
            Row() {
              Text('00:00').fontSize(10).fontColor('rgba(255,255,255,0.25)')
              Blank()
              Text('24:00').fontSize(10).fontColor('rgba(255,255,255,0.25)')
            }
            .width('100%')
            .margin({ bottom: 4 })

            Stack() {
              // 夜间背景
              Row().width('100%').height(32).borderRadius(16)
                .linearGradient({ direction: GradientDirection.Left,
                  colors: [['#1a1a3e', 0.0], ['#1a1a3e', 1.0]] })

              // 日照高亮段
              Row()
                .width(`${this.timeToPercent(this.payload.forecastDays[0].sunset) - this.timeToPercent(this.payload.forecastDays[0].sunrise)}%`)
                .height(32).borderRadius(16)
                .linearGradient({ direction: GradientDirection.Left,
                  colors: [['#ffd700', 0.0], ['#ff6b35', 0.5], ['#ffd700', 1.0]] })
                .position({ x: `${this.timeToPercent(this.payload.forecastDays[0].sunrise)}%`, y: 0 })
            }
            .width('100%')
            .height(32)
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor('rgba(255,255,255,0.05)')
        .borderRadius(16)
        .margin({ bottom: 12 })
      }

      // 7 天列表
      ForEach(this.getSunSlots(), (slot: SunSlot) => {
        Row() {
          Column() {
            Text(slot.label).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#ffffff')
            Text(slot.monthDay).fontSize(10).fontColor('rgba(255,255,255,0.35)')
          }.alignItems(HorizontalAlign.Start).width(60)

          Column() {
            Text(slot.sunrise).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#ffd700')
          }.alignItems(HorizontalAlign.Center).layoutWeight(1)

          Column() {
            Text(slot.daylightHours).fontSize(12).fontColor('rgba(255,255,255,0.50)')
          }.alignItems(HorizontalAlign.Center).layoutWeight(1)

          Column() {
            Text(slot.sunset).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#ff6b35')
          }.alignItems(HorizontalAlign.End).layoutWeight(1)
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 8, right: 8 })
        .border({ width: { bottom: 0.5 }, color: 'rgba(255,255,255,0.06)' })
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 24 })
    .backgroundColor('#1C1C1E')
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}
