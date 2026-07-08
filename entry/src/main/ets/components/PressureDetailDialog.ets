import { formatDate, getDayLabel, getWeatherIconResource } from '../utils/WeatherUtils'
import { HourlyForecastItem, ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface DaySlot {
  dateStr: string; label: string; monthDay: string
  iconDay: string; tempMax: string; tempMin: string; isToday: boolean
}

class PressurePoint {
  hour: number = 0
  pressure: number = 0
  constructor(hour: number, pressure: number) {
    this.hour = hour; this.pressure = pressure
  }
}

@CustomDialog
export struct PressureDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload
  @State @Watch('onDayChanged') selectedDayIndex: number = 1
  @StorageProp('tempUnit') tempUnit: string = '°C'

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @State chartWidth: number = 300
  @State chartHeight: number = 420

  onDayChanged(): void {
    setTimeout(() => { this.drawPressureChart() }, 50)
  }

  private getSelectedDate(): string {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    return formatDate(new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000))
  }

  private getSelectedDateFull(): string {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const d = new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000)
    const weekdays: string[] = ['日', '一', '二', '三', '四', '五', '六']
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 星期${weekdays[d.getDay()]}`
  }

  private getFilteredHourly(): HourlyForecastItem[] {
    const sel = this.getSelectedDate()
    const out: HourlyForecastItem[] = []
    for (const item of this.payload.hourlyData) {
      if (formatDate(new Date(item.fxTime)) === sel) out.push(item)
    }
    return out
  }

  private getSelectedDayForecast(): ForecastDay | null {
    const sd = this.getSelectedDate()
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    for (const f of all) { if (f.fxDate === sd) return f }
    return null
  }

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
        iconDay: fc ? fc.iconDay : '', tempMax: fc ? fc.tempMax : '--', tempMin: fc ? fc.tempMin : '--',
        isToday: i === 0
      })
    }
    return slots
  }

  @Builder CalendarStrip() {
    Column() {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.buildDaySlots(), (slot: DaySlot, idx: number) => {
            Column() {
              Text(slot.label).fontSize(11).fontColor(slot.isToday ? '#0A84FF' : 'rgba(255,255,255,0.50)')
                .fontWeight(slot.isToday ? FontWeight.Bold : FontWeight.Normal).margin({ bottom: 2 })
              Stack() {
                if (this.selectedDayIndex === idx) {
                  Circle({ width: 28, height: 28 }).fill('#0A84FF')
                }
                Text(slot.monthDay).fontSize(10)
                  .fontColor(this.selectedDayIndex === idx ? '#ffffff' : 'rgba(255,255,255,0.35)')
              }.width(28).height(28).alignContent(Alignment.Center).margin({ bottom: 4 })
              if (slot.iconDay !== '') {
                Image(getWeatherIconResource(slot.iconDay)).width(26).height(26).margin({ bottom: 3 })
              } else { Text('--').fontSize(10).fontColor('rgba(255,255,255,0.15)').margin({ bottom: 3 }) }
              Text(`${slot.tempMax}°`).fontSize(11).fontColor('rgba(255,255,255,0.70)')
              Text(`${slot.tempMin}°`).fontSize(11).fontColor('rgba(255,255,255,0.35)')
            }
            .alignItems(HorizontalAlign.Center).padding({ top: 8, bottom: 8, left: 10, right: 10 })
            .backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(12)
            .onClick(() => { this.selectedDayIndex = idx })
          })
        }.padding({ left: 4, right: 4 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      Text(this.getSelectedDateFull()).fontSize(12).fontColor('rgba(255,255,255,0.40)')
        .margin({ top: 6 })
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  private getPressureTrend(items: HourlyForecastItem[]): string {
    if (items.length < 2) return '--'
    const first = parseFloat(items[0].pressure)
    const last = parseFloat(items[items.length - 1].pressure)
    if (isNaN(first) || isNaN(last)) return '--'
    const diff = last - first
    if (diff > 1) return '↑ 上升'
    if (diff < -1) return '↓ 下降'
    return '= 平稳'
  }

  private getHourlyPressureArrow(items: HourlyForecastItem[], i: number): string {
    if (i === 0) return '--'
    const cp = parseFloat(items[i].pressure)
    const pp = parseFloat(items[i - 1].pressure)
    if (isNaN(cp) || isNaN(pp)) return '='
    if (cp > pp + 0.5) return '↑'
    if (cp < pp - 0.5) return '↓'
    return '='
  }

  private getEffectivePressureData(): PressurePoint[] {
    const hourly = this.getFilteredHourly()
    if (hourly.length >= 2) {
      const pts: PressurePoint[] = []
      for (const item of hourly) {
        const p = parseFloat(item.pressure)
        if (!isNaN(p)) pts.push(new PressurePoint(new Date(item.fxTime).getHours(), p))
      }
      if (pts.length >= 2) return pts
    }
    const fc = this.getSelectedDayForecast()
    if (!fc) return []
    const avgP = parseFloat(fc.pressure)
    if (isNaN(avgP)) return []
    const pts: PressurePoint[] = []
    for (let hour = 0; hour < 24; hour++) {
      const variation = Math.sin((hour - 10) * Math.PI / 12) * 0.8
      pts.push(new PressurePoint(hour, Math.round((avgP + variation) * 10) / 10))
    }
    return pts
  }

  private drawPressureChart(): void {
    const pts = this.getEffectivePressureData()
    if (pts.length < 2) return

    const w = this.chartWidth; const h = this.chartHeight
    if (w <= 0 || h <= 0) return

    const vals = pts.map(p => p.pressure)
    let minP = Math.min(...vals); let maxP = Math.max(...vals)
    const range = maxP - minP
    if (range < 3) { minP -= 2; maxP += 2 }
    else { minP -= range * 0.15; maxP += range * 0.15 }

    const pl = 60; const pr = 20; const pt = 28; const pb = 56
    const cw = w - pl - pr; const ch = h - pt - pb
    const toX = (i: number) => pl + (cw / (pts.length - 1)) * i
    const toY = (v: number) => pt + ch - ((v - minP) / (maxP - minP)) * ch

    const ctx = this.ctx
    ctx.clearRect(0, 0, w, h)

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'; ctx.lineWidth = 1
    const ys = 4
    for (let i = 0; i <= ys; i++) {
      const y = pt + (ch / ys) * i
      ctx.beginPath(); ctx.moveTo(pl, y); ctx.lineTo(w - pr, y); ctx.stroke()
      ctx.fillStyle = 'rgba(255,255,255,0.55)'; ctx.font = '28px sans-serif'; ctx.textAlign = 'end'
      ctx.fillText(`${Math.round(minP + ((maxP - minP) / ys) * (ys - i))}`, pl - 6, y + 10)
    }

    ctx.fillStyle = 'rgba(255,255,255,0.50)'; ctx.font = '26px sans-serif'; ctx.textAlign = 'center'
    const xs = Math.max(1, Math.floor(pts.length / 6))
    for (let i = 0; i < pts.length; i += xs) { ctx.fillText(`${pts[i].hour}`, toX(i), h - pb + 22) }
    ctx.textAlign = 'start'

    ctx.beginPath()
    ctx.moveTo(toX(0), pt + ch)
    for (let i = 0; i < pts.length; i++) ctx.lineTo(toX(i), toY(pts[i].pressure))
    ctx.lineTo(toX(pts.length - 1), pt + ch); ctx.closePath()
    const grad = ctx.createLinearGradient(0, pt, 0, pt + ch)
    grad.addColorStop(0, 'rgba(175,82,222,0.25)'); grad.addColorStop(1, 'rgba(175,82,222,0.02)')
    ctx.fillStyle = grad; ctx.fill()

    ctx.strokeStyle = '#AF52DE'; ctx.lineWidth = 2; ctx.lineJoin = 'round'
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) { if (i === 0) ctx.moveTo(toX(i), toY(pts[i].pressure)); else ctx.lineTo(toX(i), toY(pts[i].pressure)) }
    ctx.stroke()

    const xStepLabel = Math.max(1, Math.floor(pts.length / 8))
    for (let i = 0; i < pts.length; i += xStepLabel) {
      const x = toX(i); const y = toY(pts[i].pressure)
      ctx.fillStyle = '#AF52DE'; ctx.beginPath(); ctx.arc(x, y, 6, 0, Math.PI * 2); ctx.fill()
      ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.font = '28px sans-serif'; ctx.textAlign = 'center'
      ctx.fillText(`${pts[i].pressure}`, x, y - 14)
      ctx.textAlign = 'start'
    }
  }

  build() {
    Column() {
      Row() {
        Text('气压趋势').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ffffff')
        Blank()
        Button() { Image($r('sys.media.ohos_ic_public_close')).width(22).height(22).fillColor('#ffffff') }
        .width(38).height(38).backgroundColor('rgba(255,255,255,0.10)').borderRadius(19)
        .onClick(() => this.controller.close())
      }.width('100%').padding({ left: 16, right: 8, top: 10, bottom: 2 })

      this.CalendarStrip()
      Divider().color('rgba(255,255,255,0.06)').width('90%')

      Scroll() {
        Column() {
          Row({ space: 16 }) {
            Text(`${this.payload.currentWeather?.pressure || '--'} hPa`).fontSize(36).fontWeight(FontWeight.Bold).fontColor('#AF52DE')
            Column({ space: 4 }) {
              Text(this.getPressureTrend(this.getFilteredHourly())).fontSize(16)
                .fontColor(this.getPressureTrend(this.getFilteredHourly()).includes('↑') ? '#ff9f43'
                  : (this.getPressureTrend(this.getFilteredHourly()).includes('↓') ? '#5AC8FA' : '#8E8E93'))
              Text(this.getPressureDesc(Number(this.payload.currentWeather?.pressure))).fontSize(13).fontColor('rgba(255,255,255,0.40)')
            }.alignItems(HorizontalAlign.Start)
          }.width('100%').padding(16)

          if (this.getEffectivePressureData().length >= 2) {
            Row({ space: 2 }) {
              ForEach(this.getFilteredHourly(), (item: HourlyForecastItem, i: number) => {
                Text(this.getHourlyPressureArrow(this.getFilteredHourly(), i))
                  .fontSize(16)
                  .fontColor(this.getHourlyPressureArrow(this.getFilteredHourly(), i) === '↑' ? '#ff9f43'
                    : (this.getHourlyPressureArrow(this.getFilteredHourly(), i) === '↓' ? '#5AC8FA' : '#8E8E93'))
              })
            }.width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 46, right: 16, bottom: 4 })
          }

          if (this.getEffectivePressureData().length >= 2) {
            Canvas(this.ctx)
              .width('100%').height(400)
              .onAreaChange((_old: Area, nv: Area) => { const nw = nv.width as number; const nh = nv.height as number; if (nw > 0) this.chartWidth = nw; if (nh > 0) this.chartHeight = nh })
              .onReady(() => { this.drawPressureChart() })
          }

          if (this.getEffectivePressureData().length < 2) {
            Column({ space: 8 }) {
              Text(`${this.getSelectedDate()}`).fontSize(14).fontColor('rgba(255,255,255,0.40)')
              Text('暂无该日逐小时气压数据（仅当天支持逐小时图表）').fontSize(13).fontColor('rgba(255,255,255,0.30)')
              if (this.getSelectedDayForecast() !== null) {
                Text(`气压: ${this.getSelectedDayForecast()!.pressure || '--'} hPa`).fontSize(16).fontColor('#AF52DE').margin({ top: 8 })
              }
            }.width('100%').padding({ top: 30, bottom: 30 }).alignItems(HorizontalAlign.Center)
          }

          Column({ space: 4 }) {
            Text('每日摘要').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text(this.getPressureSummary()).fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 14, left: 12, right: 12 })

          Column({ space: 4 }) {
            Text('你知道吗？').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text('气压的显著急剧变化可用于预测天气变化。气压急剧下降通常预示暴风雨即将来临；气压上升则预示天气将转好。标准海平面气压为 1013.25 hPa。')
              .fontSize(12).fontColor('rgba(255,255,255,0.45)').lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 10, left: 12, right: 12 })

          Blank().height(40)
        }.width('100%')
      }.scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off).layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('94%')
    .backgroundColor('#1C1C1E')
    .borderRadius({ topLeft: 20, topRight: 20 }).padding({ bottom: 16 })
  }

  private getPressureDesc(p: number): string {
    if (isNaN(p)) return ''
    if (p > 1025) return '偏高'; if (p < 1005) return '偏低'; return '正常'
  }

  private getPressureSummary(): string {
    const filtered = this.getFilteredHourly()
    if (filtered.length === 0) {
      const cur = this.payload.currentWeather
      return cur ? `当前气压${cur.pressure}hPa，${this.getPressureDesc(Number(cur.pressure))}。` : '暂无气压数据。'
    }
    let min = 9999; let max = -9999; let sum = 0; let count = 0
    for (const item of filtered) {
      const p = parseFloat(item.pressure); if (!isNaN(p)) { if (p < min) min = p; if (p > max) max = p; sum += p; count++ }
    }
    if (count === 0) return '暂无气压数据。'
    return `平均气压为${(sum / count).toFixed(2)} hPa，最低气压为${min} hPa，趋势${this.getPressureTrend(filtered)}。`
  }
}
