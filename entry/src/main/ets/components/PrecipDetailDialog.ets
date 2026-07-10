/**
 * 降水详情弹窗
 * 24h 降水概率柱状图 + 明日降水 + 7 天降水概览
 */
import { formatDate, getDayLabel } from '../utils/WeatherUtils'
import { HourlyForecastItem, ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface PrecipSlot {
  dateStr: string; label: string; monthDay: string
  pop: string; precip: string  // daily pop (max hourly) + daily precip
}

@CustomDialog
export struct PrecipDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload

  private getFilteredHourly(): HourlyForecastItem[] {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const ds = formatDate(today)
    const out: HourlyForecastItem[] = []
    for (const item of this.payload.hourlyData) {
      if (formatDate(new Date(item.fxTime)) === ds) out.push(item)
    }
    return out
  }

  private getMaxPop(items: HourlyForecastItem[]): number {
    let max = 0
    for (const item of items) {
      const v = parseFloat(item.pop)
      if (!isNaN(v) && v > max) max = v
    }
    return max
  }

  private getPrecipSlots(): PrecipSlot[] {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const all = this.payload.forecastDays
    const slots: PrecipSlot[] = []
    for (let i = 0; i < 7; i++) {
      const d = new Date(today.getTime() + i * 86400000)
      const ds = formatDate(d)
      const fc = all.find((f: ForecastDay) => f.fxDate === ds)
      if (!fc) continue
      let pop = ''
      if (i === 0) {
        const maxPop = this.getMaxPop(this.getFilteredHourly())
        pop = maxPop > 0 ? `${maxPop}%` : (fc.precip && fc.precip !== '0.0' ? `${fc.precip}%` : '--')
      }
      slots.push({
        dateStr: ds,
        label: getDayLabel(ds),
        monthDay: `${d.getMonth() + 1}/${d.getDate()}`,
        pop: pop || '--',
        precip: fc.precip || '--'
      })
    }
    return slots
  }

  build() {
    Column() {
      // 标题栏 + X 关闭按钮
      Row() {
        Text(`${this.payload.cityName} · 降水`)
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

      // 今日降水
      if (this.getFilteredHourly().length > 0) {
        Column() {
          Text('24h 降水概率').fontSize(14).fontColor('rgba(255,255,255,0.50)')
            .margin({ bottom: 10 }).alignSelf(ItemAlign.Start)

          // 柱状图
          Column() {
            Row() {
              ForEach(this.getFilteredHourly(), (item: HourlyForecastItem) => {
                Column() {
                  Text(`${parseFloat(item.pop) || 0}%`)
                    .fontSize(9).fontColor('rgba(255,255,255,0.50)')
                    .margin({ bottom: 2 })
                  Column()
                    .width(6)
                    .height(Math.max(4, (parseFloat(item.pop) || 0) * 0.8))
                    .borderRadius(3)
                    .backgroundColor(this.getPopBarColor(parseFloat(item.pop)))
                  Text(new Date(item.fxTime).getHours().toString())
                    .fontSize(8).fontColor('rgba(255,255,255,0.30)')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Center)
                .layoutWeight(1)
              })
            }
            .width('100%')
            .height(100)
            .alignItems(VerticalAlign.Bottom)
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor('rgba(255,255,255,0.05)')
        .borderRadius(16)
        .margin({ bottom: 12 })
      }

      // 今日 vs 明日对照
      if (this.payload.forecastDays.length >= 2) {
        Column() {
          Text('今日 vs 明日').fontSize(14).fontColor('rgba(255,255,255,0.50)')
            .margin({ bottom: 10 }).alignSelf(ItemAlign.Start)

          Row() {
            // 今日
            Column() {
              Text('今天').fontSize(12).fontColor('rgba(255,255,255,0.40)').margin({ bottom: 4 })
              Text(this.payload.forecastDays[0].precip ? `${this.payload.forecastDays[0].precip} mm` : '--')
                .fontSize(22).fontWeight(FontWeight.Bold)
                .fontColor('#74b9ff')
              Text(this.payload.forecastDays[0].textDay || '')
                .fontSize(11).fontColor('rgba(255,255,255,0.35)')
                .margin({ top: 2 }).maxLines(1)
            }
            .alignItems(HorizontalAlign.Center).layoutWeight(1)

            // 箭头分隔
            Image($r('sys.media.ohos_ic_public_arrow_right'))
              .width(16).height(16).fillColor('rgba(255,255,255,0.25)')

            // 明日
            Column() {
              Text('明天').fontSize(12).fontColor('rgba(255,255,255,0.40)').margin({ bottom: 4 })
              Text(this.payload.forecastDays[1].precip ? `${this.payload.forecastDays[1].precip} mm` : '--')
                .fontSize(22).fontWeight(FontWeight.Bold)
                .fontColor('#a29bfe')
              Text(this.payload.forecastDays[1].textDay || '')
                .fontSize(11).fontColor('rgba(255,255,255,0.35)')
                .margin({ top: 2 }).maxLines(1)
            }
            .alignItems(HorizontalAlign.Center).layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor('rgba(255,255,255,0.05)')
        .borderRadius(16)
        .margin({ bottom: 12 })
      }

      // 7 天降水列表
      Text('逐日降水').fontSize(14).fontColor('rgba(255,255,255,0.50)').margin({ bottom: 8 }).alignSelf(ItemAlign.Start).padding({ left: 4 })

      ForEach(this.getPrecipSlots(), (slot: PrecipSlot) => {
        Row() {
          Column() {
            Text(slot.label).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#ffffff')
            Text(slot.monthDay).fontSize(10).fontColor('rgba(255,255,255,0.35)')
          }.alignItems(HorizontalAlign.Start).width(60)

          Column() {
            Text(slot.pop).fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.getPopProbColor(slot.pop))
          }.alignItems(HorizontalAlign.Center).layoutWeight(0.8)

          Column() {
            Row() {
              Text(slot.precip !== '0.0' && slot.precip ? `${slot.precip}` : '--')
                .fontSize(12).fontColor('rgba(255,255,255,0.50)')
              if (slot.precip !== '0.0' && slot.precip) {
                Text(' mm').fontSize(10).fontColor('rgba(255,255,255,0.30)')
              }
            }
          }.alignItems(HorizontalAlign.End).layoutWeight(1.2)
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

  private getPopBarColor(pop: number): string {
    if (isNaN(pop)) return 'rgba(255,255,255,0.15)'
    if (pop >= 80) return '#74b9ff'
    if (pop >= 50) return '#a29bfe'
    if (pop >= 20) return '#81ecec'
    return 'rgba(255,255,255,0.15)'
  }

  private getPopProbColor(pop: string): string {
    if (!pop || pop === '--') return 'rgba(255,255,255,0.30)'
    const v = parseFloat(pop)
    if (isNaN(v)) return 'rgba(255,255,255,0.30)'
    if (v >= 80) return '#74b9ff'
    if (v >= 50) return '#a29bfe'
    return 'rgba(255,255,255,0.50)'
  }
}
