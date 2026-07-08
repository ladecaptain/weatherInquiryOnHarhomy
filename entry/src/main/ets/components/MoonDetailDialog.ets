/**
 * 月相详情弹窗
 * 当月月相大图标 + 月出/月落 + 7 天月相列表
 */
import { formatDate, getDayLabel } from '../utils/WeatherUtils'
import { ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface MoonSlot {
  dateStr: string; label: string; monthDay: string
  moonPhase: string; moonPhaseIcon: string
  moonrise: string; moonset: string
}

@CustomDialog
export struct MoonDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload

  private getMoonSlots(): MoonSlot[] {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const all = this.payload.forecastDays
    const slots: MoonSlot[] = []
    for (let i = 0; i < all.length && slots.length < 7; i++) {
      const d = new Date(today.getTime() + i * 86400000)
      const ds = formatDate(d)
      const fc = all[i]
      slots.push({
        dateStr: ds,
        label: getDayLabel(ds),
        monthDay: `${d.getMonth() + 1}/${d.getDate()}`,
        moonPhase: fc.moonPhase || '未知',
        moonPhaseIcon: fc.moonPhaseIcon || '',
        moonrise: fc.moonrise || '',
        moonset: fc.moonset || ''
      })
    }
    return slots
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

  build() {
    Column() {
      // 标题栏 + X 关闭按钮
      Row() {
        Text(`${this.payload.cityName} · 月相`)
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
        // 当月月相大卡片
        Column() {
          Text(this.getMoonEmoji(this.payload.forecastDays[0].moonPhaseIcon))
            .fontSize(72)
            .margin({ bottom: 8 })

          Text(this.payload.forecastDays[0].moonPhase || '未知')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
            .margin({ bottom: 16 })

          Row() {
            Column() {
              Text('月出').fontSize(12).fontColor('rgba(255,255,255,0.40)').margin({ bottom: 4 })
              Text(this.payload.forecastDays[0].moonrise || '--').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ffd700')
            }.alignItems(HorizontalAlign.Center).layoutWeight(1)

            Column() {
              Text('月落').fontSize(12).fontColor('rgba(255,255,255,0.40)').margin({ bottom: 4 })
              Text(this.payload.forecastDays[0].moonset || '--').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#a29bfe')
            }.alignItems(HorizontalAlign.Center).layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('rgba(255,255,255,0.05)')
        .borderRadius(16)
        .margin({ bottom: 12 })
      }

      // 7 天月相列表
      Text('逐日月相').fontSize(14).fontColor('rgba(255,255,255,0.50)').margin({ bottom: 8 }).alignSelf(ItemAlign.Start).padding({ left: 4 })

      ForEach(this.getMoonSlots(), (slot: MoonSlot) => {
        Row() {
          Column() {
            Text(slot.label).fontSize(12).fontWeight(FontWeight.Medium).fontColor('#ffffff')
            Text(slot.monthDay).fontSize(10).fontColor('rgba(255,255,255,0.35)')
          }.alignItems(HorizontalAlign.Start).width(60)

          Column() {
            Text(this.getMoonEmoji(slot.moonPhaseIcon)).fontSize(28)
          }.alignItems(HorizontalAlign.Center).layoutWeight(0.5)

          Column() {
            Text(slot.moonPhase).fontSize(13).fontColor('rgba(255,255,255,0.70)')
            Text(slot.moonrise ? `↑${slot.moonrise}` : '').fontSize(11).fontColor('rgba(255,255,255,0.35)')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)

          Column() {
            Text(slot.moonset ? `↓${slot.moonset}` : '').fontSize(11).fontColor('rgba(255,255,255,0.35)')
          }.alignItems(HorizontalAlign.End).layoutWeight(0.8)
        }
        .width('100%')
        .height(48)
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
