import { formatDate, getDayLabel, getWeatherIconResource } from '../utils/WeatherUtils'
import { HourlyForecastItem, ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface DaySlot {
  dateStr: string; label: string; monthDay: string
  iconDay: string; tempMax: string; tempMin: string; isToday: boolean
}

class HumidityPoint {
  hour: number = 0
  humidity: number = 0
  constructor(hour: number, humidity: number) {
    this.hour = hour; this.humidity = humidity
  }
}

@CustomDialog
export struct HumidityDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload
  @State @Watch('onDayChanged') selectedDayIndex: number = 1
  @StorageProp('tempUnit') tempUnit: string = '°C'

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @State chartWidth: number = 300
  @State chartHeight: number = 420

  onDayChanged(): void {
    setTimeout(() => { this.drawHumidityChart() }, 50)
  }

  private getSelectedDate(): string {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    return formatDate(new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000))
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
                  Circle().width(30).height(30).fill('#0A84FF')
                }
                Text(slot.monthDay).fontSize(11)
                  .fontColor(this.selectedDayIndex === idx ? '#ffffff' : 'rgba(255,255,255,0.50)')
                  .fontWeight(this.selectedDayIndex === idx ? FontWeight.Bold : FontWeight.Normal)
              }.width(30).height(30).alignContent(Alignment.Center).margin({ bottom: 4 })
              if (slot.iconDay !== '') {
                Image(getWeatherIconResource(slot.iconDay)).width(26).height(26).margin({ bottom: 3 })
              } else { Text('--').fontSize(10).fontColor('rgba(255,255,255,0.15)').margin({ bottom: 3 }) }
              Text(`${slot.tempMax}°`).fontSize(11).fontColor('rgba(255,255,255,0.70)')
              Text(`${slot.tempMin}°`).fontSize(11).fontColor('rgba(255,255,255,0.35)')
            }
            .alignItems(HorizontalAlign.Center).padding({ top: 8, bottom: 8, left: 10, right: 10 })
            .borderRadius(12)
            .onClick(() => { this.selectedDayIndex = idx })
          })
        }.padding({ left: 4, right: 4 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      Text(this.getSelectedDate()).fontSize(12).fontColor('rgba(255,255,255,0.40)')
        .margin({ top: 4 })
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

  private getEffectiveHumidityData(): HumidityPoint[] {
    const hourly = this.getFilteredHourly()
    if (hourly.length >= 2) {
      const pts: HumidityPoint[] = []
      for (const item of hourly) {
        const h = parseFloat(item.humidity)
        if (!isNaN(h)) pts.push(new HumidityPoint(new Date(item.fxTime).getHours(), h))
      }
      if (pts.length >= 2) return pts
    }
    const fc = this.getSelectedDayForecast()
    if (!fc) return []
    const avgH = parseFloat(fc.humidity)
    if (isNaN(avgH)) return []
    const pts: HumidityPoint[] = []
    for (let hour = 0; hour < 24; hour++) {
      const distFrom5am = Math.min(Math.abs(hour - 5), 24 - Math.abs(hour - 5))
      const factor = 1 - 0.25 * (1 - distFrom5am / 12)
      pts.push(new HumidityPoint(hour, Math.min(100, Math.max(0, Math.round(avgH * factor)))))
    }
    return pts
  }

  private drawHumidityChart(): void {
    const pts = this.getEffectiveHumidityData()
    if (pts.length < 2) return

    const w = this.chartWidth; const h = this.chartHeight
    if (w <= 0 || h <= 0) return

    let minH = Math.min(...pts.map(p => p.humidity)) - 8
    let maxH = Math.max(...pts.map(p => p.humidity)) + 8
    if (minH < 0) minH = 0; if (maxH > 100) maxH = 100
    if (maxH - minH < 20) { const mid = (maxH + minH) / 2; minH = mid - 10; maxH = mid + 10 }

    const pl = 52; const pr = 20; const pt = 28; const pb = 56
    const cw = w - pl - pr; const ch = h - pt - pb
    const toX = (i: number) => pl + (cw / (pts.length - 1)) * i
    const toY = (v: number) => pt + ch - ((v - minH) / (maxH - minH)) * ch

    const ctx = this.ctx
    ctx.clearRect(0, 0, w, h)

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'; ctx.lineWidth = 1
    for (let i = 0; i <= 4; i++) {
      const y = pt + (ch / 4) * i
      ctx.beginPath(); ctx.moveTo(pl, y); ctx.lineTo(w - pr, y); ctx.stroke()
      ctx.fillStyle = 'rgba(255,255,255,0.55)'; ctx.font = '28px sans-serif'; ctx.textAlign = 'end'
      ctx.fillText(`${Math.round(minH + ((maxH - minH) / 4) * (4 - i))}%`, pl - 6, y + 10)
    }

    ctx.fillStyle = 'rgba(255,255,255,0.50)'; ctx.font = '26px sans-serif'; ctx.textAlign = 'center'
    const xs = Math.max(1, Math.floor(pts.length / 6))
    for (let i = 0; i < pts.length; i += xs) { ctx.fillText(`${pts[i].hour}`, toX(i), h - pb + 22) }
    ctx.textAlign = 'start'

    ctx.beginPath(); ctx.moveTo(toX(0), pt + ch)
    for (let i = 0; i < pts.length; i++) ctx.lineTo(toX(i), toY(pts[i].humidity))
    ctx.lineTo(toX(pts.length - 1), pt + ch); ctx.closePath()
    const grad = ctx.createLinearGradient(0, pt, 0, pt + ch)
    grad.addColorStop(0, 'rgba(120,80,220,0.40)'); grad.addColorStop(1, 'rgba(60,140,255,0.02)')
    ctx.fillStyle = grad; ctx.fill()

    ctx.strokeStyle = '#9B59B6'; ctx.lineWidth = 4; ctx.lineJoin = 'round'
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) { if (i === 0) ctx.moveTo(toX(i), toY(pts[i].humidity)); else ctx.lineTo(toX(i), toY(pts[i].humidity)) }
    ctx.stroke()

    const xStepLabel = Math.max(1, Math.floor(pts.length / 8))
    for (let i = 0; i < pts.length; i += xStepLabel) {
      const x = toX(i); const y = toY(pts[i].humidity)
      ctx.fillStyle = '#9B59B6'; ctx.beginPath(); ctx.arc(x, y, 6, 0, Math.PI * 2); ctx.fill()
      ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.font = '28px sans-serif'; ctx.textAlign = 'center'
      ctx.fillText(`${pts[i].humidity}%`, x, y - 14)
      ctx.textAlign = 'start'
    }
  }

  build() {
    Column() {
      Row() {
        Text('湿度趋势').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ffffff')
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
            Text(`${this.payload.currentWeather?.humidity || '--'}%`).fontSize(42).fontWeight(FontWeight.Bold).fontColor('#9B59B6')
            Column({ space: 4 }) {
              Text('相对湿度').fontSize(13).fontColor('rgba(255,255,255,0.40)')
              Text(`露点温度: ${this.payload.currentWeather?.dew || '--'}°`).fontSize(14).fontColor('#ffffff')
            }.alignItems(HorizontalAlign.Start)
          }.width('100%').padding(16)

          if (this.getEffectiveHumidityData().length >= 2) {
            Canvas(this.ctx)
              .width('100%').height(400)
              .onAreaChange((_old: Area, nv: Area) => { const nw = nv.width as number; const nh = nv.height as number; if (nw > 0) this.chartWidth = nw; if (nh > 0) this.chartHeight = nh })
              .onReady(() => { this.drawHumidityChart() })
          }

          Column({ space: 4 }) {
            Text('每日摘要').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text(this.getHumiditySummary()).fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
              .fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 16, left: 12, right: 12 })

          Column({ space: 4 }) {
            Text('每日比较').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text(this.getHumidityComparison()).fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 10, left: 12, right: 12 })

          if (this.getEffectiveHumidityData().length < 2) {
            Column({ space: 8 }) {
              Text(`${this.getSelectedDate()}`).fontSize(14).fontColor('rgba(255,255,255,0.40)')
              Text('暂无该日逐小时湿度数据（仅当天支持逐小时图表）').fontSize(13).fontColor('rgba(255,255,255,0.30)')
              if (this.getSelectedDayForecast() !== null) {
                Text(`日均湿度: ${this.getSelectedDayForecast()!.humidity || '--'}%`).fontSize(16).fontColor('#9B59B6').margin({ top: 8 })
              }
            }.width('100%').padding({ top: 30, bottom: 30 }).alignItems(HorizontalAlign.Center)
          }

          Blank().height(40)
        }.width('100%')
      }.scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off).layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('94%')
    .backgroundColor('#1C1C1E')
    .borderRadius({ topLeft: 20, topRight: 20 }).padding({ bottom: 16 })
  }

  private getHumiditySummary(): string {
    const pts = this.getEffectiveHumidityData()
    if (pts.length >= 2) {
      let sum = 0; let count = 0
      for (const p of pts) { sum += p.humidity; count++ }
      return `平均湿度为${count > 0 ? Math.round(sum / count) : '--'}%。`
    }
    const fc = this.getSelectedDayForecast()
    return fc ? `日均湿度: ${fc.humidity || '--'}%。` : '暂无数据'
  }

  private getHumidityComparison(): string {
    const fc = this.getSelectedDayForecast()
    if (!fc) return '暂无比较数据。'
    const h = Number(fc.humidity)
    if (isNaN(h)) return '暂无比较数据。'
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    const idx = all.findIndex((f: ForecastDay) => f.fxDate === fc.fxDate)
    if (idx > 0) {
      const prevH = Number(all[idx - 1].humidity)
      if (!isNaN(prevH)) {
        if (h > prevH) return '今天平均湿度比昨天高。'
        if (h < prevH) return '今天平均湿度比昨天低。'
        return '今天湿度与昨天类似。'
      }
    }
    return `今日相对湿度为 ${h}%。`
  }
}
