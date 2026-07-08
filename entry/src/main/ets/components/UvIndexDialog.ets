/**
 * 紫外线指数详情弹窗
 * 基于每日预报数据展示 UV 指数 & 健康建议
 */
import { formatDate, getDayLabel } from '../utils/WeatherUtils'
import { ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface DaySlot {
  dateStr: string; label: string; monthDay: string; uvIndex: string; isToday: boolean
}

@CustomDialog
export struct UvIndexDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload
  @State selectedDayIndex: number = 1

  /* ── 日期 ── */
  private getSelectedDate(): string {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    return formatDate(new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000))
  }

  private getSelectedForecast(): ForecastDay | null {
    const sd = this.getSelectedDate()
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    for (const f of all) { if (f.fxDate === sd) return f }
    return null
  }

  /* ── 日历 ── */
  private buildDaySlots(): DaySlot[] {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    const slots: DaySlot[] = []
    for (let i = -1; i <= 5; i++) {
      const d = new Date(today.getTime() + i * 86400000); const ds = formatDate(d)
      const fc = all.find((f: ForecastDay) => f.fxDate === ds)
      slots.push({
        dateStr: ds, label: getDayLabel(ds),
        monthDay: `${d.getMonth() + 1}/${d.getDate()}`,
        uvIndex: fc ? fc.uvIndex : '--', isToday: i === 0
      })
    }
    return slots
  }

  @Builder CalendarStrip() {
    Row() {
      Scroll() {
        Row({ space: 12 }) {
          ForEach(this.buildDaySlots(), (slot: DaySlot, idx: number) => {
            Column() {
              Text(slot.label).fontSize(11).fontColor(slot.isToday ? '#6db3f2' : 'rgba(255,255,255,0.50)')
                .fontWeight(slot.isToday ? FontWeight.Bold : FontWeight.Normal).margin({ bottom: 2 })
              Text(slot.monthDay).fontSize(10).fontColor('rgba(255,255,255,0.35)').margin({ bottom: 6 })
              Text(slot.uvIndex).fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(slot.uvIndex !== '--' ? this.getUvColor(Number(slot.uvIndex)) : 'rgba(255,255,255,0.25)')
            }
            .alignItems(HorizontalAlign.Center).padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .backgroundColor(this.selectedDayIndex === idx ? 'rgba(109,179,242,0.18)' : 'rgba(255,255,255,0.04)')
            .borderRadius(14).border({ width: this.selectedDayIndex === idx ? 1.5 : 0, color: 'rgba(109,179,242,0.55)' })
            .onClick(() => { this.selectedDayIndex = idx })
          })
        }.padding({ left: 6, right: 6 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
    }.width('100%').padding({ top: 10, bottom: 10 })
  }

  /* ── UV 等级 ── */
  getUvColor(uv: number): string {
    if (uv <= 2) return '#00e676'; if (uv <= 5) return '#ffd600'
    if (uv <= 7) return '#ff9100'; if (uv <= 10) return '#ff5252'; return '#d500f9'
  }

  getUvLevel(uv: number): string {
    if (uv <= 2) return '低'; if (uv <= 5) return '中等'
    if (uv <= 7) return '高'; if (uv <= 10) return '很高'; return '极高'
  }

  getUvAdvice(uv: number): string {
    if (uv <= 2) return '无需特殊防护，可放心外出活动。'
    if (uv <= 5) return '建议涂抹防晒霜，佩戴帽子和太阳镜。'
    if (uv <= 7) return '建议减少户外活动，必须外出时做好全面防护。'
    if (uv <= 10) return '尽量避免10:00-16:00外出，使用高倍防晒。'
    return '请勿在紫外线最强烈时段外出，全面防护。'
  }

  /* 计算 UV 相关指标 */
  private getUvVal(): number {
    const fc = this.getSelectedForecast()
    const uv = fc ? Number(fc.uvIndex) : NaN
    return isNaN(uv) ? 0 : uv
  }

  private getUvDisplayColor(): string {
    return this.getUvColor(this.getUvVal())
  }

  private getUvDisplayLevel(): string {
    return this.getUvLevel(this.getUvVal())
  }

  build() {
    Column() {
      Row() {
        Text('紫外线指数').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ffffff')
        Blank()
        Button() { Image($r('sys.media.ohos_ic_public_close')).width(22).height(22).fillColor('#ffffff') }
        .width(38).height(38).backgroundColor('rgba(255,255,255,0.10)').borderRadius(19)
        .onClick(() => this.controller.close())
      }.width('100%').padding({ left: 16, right: 8, top: 10, bottom: 2 })

      this.CalendarStrip()
      Divider().color('rgba(255,255,255,0.06)').width('90%')

      Scroll() {
        Column() {
          // 大字 UVI
          Column({ space: 6 }) {
            Text(this.getSelectedForecast()?.uvIndex ?? '--')
              .fontSize(56).fontWeight(FontWeight.Bold).fontColor(this.getUvDisplayColor())
            Text(`${this.getUvVal()} | ${this.getUvDisplayLevel()}`)
              .fontSize(16).fontColor(this.getUvDisplayColor())
            Text('基于世界卫生组织 UVI 标准').fontSize(10).fontColor('rgba(255,255,255,0.25)')
          }.width('100%').padding(20).alignItems(HorizontalAlign.Center)

          // UV 渐变条
          if (this.getSelectedForecast() !== null && !isNaN(this.getUvVal())) {
            Column() {
              Row() { Text('0').fontSize(10).fontColor('#00e676')
                Blank(); Text('2').fontSize(10).fontColor('#ffd600')
                Blank(); Text('5').fontSize(10).fontColor('#ff9100')
                Blank(); Text('7').fontSize(10).fontColor('#ff5252')
                Blank(); Text('11+').fontSize(10).fontColor('#d500f9')
              }.width('100%').padding({ left: 4, right: 4 })

              Stack() {
                Row().width('100%').height(10).borderRadius(5)
                  .linearGradient({ direction: GradientDirection.Right, colors: [['#00e676', 0], ['#ffd600', 0.2], ['#ff9100', 0.45], ['#ff5252', 0.7], ['#d500f9', 1]] })
                Circle().width(14).height(14).fill(this.getUvDisplayColor()).stroke(Color.White).strokeWidth(2)
                  .position({ x: `${Math.min(this.getUvVal() / 11 * 100, 100)}%`, y: -2 }).translate({ x: -7 })
              }.width('100%').height(14).margin({ top: 4, bottom: 4 })
            }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
          }

          // 健康建议
          Column({ space: 8 }) {
            Text('防护建议').fontSize(14).fontColor('rgba(255,255,255,0.40)')
              .margin({ bottom: 4 })
            Text(this.getUvAdvice(this.getUvVal())).fontSize(13).fontColor('rgba(255,255,255,0.65)')
              .lineHeight(20)
            if (this.getUvVal() > 2) {
              Text('今日 09:00 至 17:00 紫外线达到中等或更高等级，请注意防护。')
                .fontSize(12).fontColor('rgba(255,255,255,0.35)').lineHeight(18).margin({ top: 6 })
            }
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 14, left: 12, right: 12 })

          // 每日比较
          Column({ space: 4 }) {
            Text('每日比较').fontSize(13).fontColor('rgba(255,255,255,0.30)')
              .margin({ bottom: 4 })
            Text(this.getUvComparison()).fontSize(12).fontColor('rgba(255,255,255,0.50)')
              .lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 10, left: 12, right: 12 })

          // 兜底
          if (!this.getSelectedForecast()) {
            Text('暂无该日紫外线数据').fontSize(14).fontColor('rgba(255,255,255,0.30)')
              .padding({ top: 40, bottom: 40 })
          }

          Blank().height(40)
        }.width('100%')
      }.scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off).layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('94%')
    .backgroundColor('#1a1d28')
    .borderRadius({ topLeft: 20, topRight: 20 }).padding({ bottom: 16 })
  }

  private getUvComparison(): string {
    const fc = this.getSelectedForecast()
    if (!fc) return '暂无比较数据。'
    const uv = Number(fc.uvIndex)
    if (isNaN(uv)) return '暂无比较数据。'
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    const idx = all.findIndex((f: ForecastDay) => f.fxDate === fc.fxDate)
    if (idx > 0) {
      const prevUv = Number(all[idx - 1].uvIndex)
      if (!isNaN(prevUv)) {
        if (uv > prevUv) return `今天最高紫外线指数比昨天高。`
        if (uv < prevUv) return `今天最高紫外线指数比昨天低。`
        return `今天最高紫外线指数与昨天类似。`
      }
    }
    return `今日紫外线等级：${this.getUvLevel(uv)}。`
  }
}
