import { formatTempWithUnit } from '../services/TemperatureService'
import { formatDate, getDayLabel, getWeatherIconResource } from '../utils/WeatherUtils'
import { HourlyForecastItem, ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface DaySlot {
  dateStr: string; label: string; monthDay: string; dayNum: number
  iconDay: string; tempMax: string; tempMin: string; isToday: boolean
}

interface ChartPoint {
  hour: number; value: number; icon: string; text: string
}

class PrecipPoint {
  hour: number = 0; pop: number = 0
  constructor(hour: number, pop: number) { this.hour = hour; this.pop = pop }
}

@CustomDialog
export struct TemperatureTrendDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload
  @Watch('onDayChanged') @State selectedDayIndex: number = 1
  @StorageProp('tempUnit') tempUnit: string = '°C'

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @State chartWidth: number = 350
  @State chartHeight: number = 220

  private precipSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private precipCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.precipSettings)
  @State precipChartWidth: number = 350

  onDayChanged(): void { this.redrawCharts() }

  private getSelectedDate(): string {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    return formatDate(new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000))
  }

  private isToday(): boolean {
    return this.getSelectedDate() === formatDate(new Date())
  }

  private getSelectedFullDate(): string {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const d = new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000)
    const weekdays = ['日', '一', '二', '三', '四', '五', '六']
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

  private generateDayChartPoints(fc: ForecastDay): ChartPoint[] {
    const tMax = parseFloat(fc.tempMax)
    const tMin = parseFloat(fc.tempMin)
    if (isNaN(tMax) || isNaN(tMin)) return []
    const tDayIcon = fc.iconDay || '100'
    const tNightIcon = fc.iconNight || '150'
    const points: ChartPoint[] = []
    const keyHours: number[] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
    const keyWeights: number[] = [0.0, 0.02, 0.05, 0.1, 0.35, 0.55, 1.0, 0.85, 0.65, 0.35, 0.15, 0.05]
    for (let i = 0; i < keyHours.length; i++) {
      const w = keyWeights[i]
      const t = tMin + (tMax - tMin) * w
      const icon = (keyHours[i] >= 6 && keyHours[i] <= 18) ? tDayIcon : tNightIcon
      const text = (keyHours[i] >= 6 && keyHours[i] <= 18) ? fc.textDay : fc.textNight
      points.push({ hour: keyHours[i], value: this.convertTemp(t), icon: icon, text: text ?? '' })
    }
    return points
  }

  private generateDayPrecipPoints(fc: ForecastDay): PrecipPoint[] {
    const precipVal = parseFloat(fc.precip)
    const points: PrecipPoint[] = []
    const keyHours: number[] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
    let popBase = 0
    if (!isNaN(precipVal) && precipVal > 0) {
      popBase = Math.min(80, precipVal * 40)
    }
    const popWeights: number[] = [0.3, 0.3, 0.4, 0.6, 0.8, 0.8, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]
    for (let i = 0; i < keyHours.length; i++) {
      points.push(new PrecipPoint(keyHours[i], Math.min(100, popBase * popWeights[i])))
    }
    return points
  }

  private getEffectiveChartPoints(): ChartPoint[] {
    if (this.isToday()) {
      const allHourly = this.payload.hourlyData
      if (allHourly.length >= 2) {
        return this.sampleTo12Points(allHourly)
      }
    }
    const hourly = this.getFilteredHourly()
    if (hourly.length >= 2) {
      return this.sampleTo12Points(hourly)
    }
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return this.generateDayChartPoints(fc)
    }
    return []
  }

  private sampleTo12Points(hourly: HourlyForecastItem[]): ChartPoint[] {
    const targetHours = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
    const points: ChartPoint[] = []
    for (const th of targetHours) {
      let best: HourlyForecastItem | null = null
      let bestDist = 999
      for (const item of hourly) {
        const h = new Date(item.fxTime).getHours()
        const dist = Math.abs(h - th)
        if (dist < bestDist) {
          bestDist = dist
          best = item
        }
      }
      if (best) {
        const t = parseFloat(best.temp)
        if (!isNaN(t)) {
          points.push({ hour: th, value: this.convertTemp(t), icon: best.icon, text: best.text })
        }
      }
    }
    return points
  }

  private getEffectivePrecipPoints(): PrecipPoint[] {
    const hourly = this.getFilteredHourly()
    if (hourly.length >= 2) {
      const pts: PrecipPoint[] = []
      for (const item of hourly) {
        const p = parseFloat(item.pop)
        if (!isNaN(p)) pts.push(new PrecipPoint(new Date(item.fxTime).getHours(), p))
      }
      if (pts.length >= 2) return pts
    }
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return this.generateDayPrecipPoints(fc)
    }
    return []
  }

  private hasChartableData(): boolean {
    return this.getEffectiveChartPoints().length >= 2
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
        monthDay: `${d.getMonth() + 1}/${d.getDate()}`, dayNum: d.getDate(),
        iconDay: fc ? fc.iconDay : '', tempMax: fc ? fc.tempMax : '--', tempMin: fc ? fc.tempMin : '--',
        isToday: i === 0
      })
    }
    return slots
  }

  @Builder CalendarStrip() {
    Column() {
      Scroll() {
        Row({ space: 4 }) {
          ForEach(this.buildDaySlots(), (slot: DaySlot, idx: number) => {
            Column() {
              Text(slot.label).fontSize(10).fontColor('rgba(255,255,255,0.50)').margin({ bottom: 4 })
              Stack() {
                Circle().width(30).height(30).fill(this.selectedDayIndex === idx ? '#0A84FF' : Color.Transparent)
                Text(`${slot.dayNum}`).fontSize(14)
                  .fontColor(this.selectedDayIndex === idx ? '#ffffff' : 'rgba(255,255,255,0.80)')
                  .fontWeight(this.selectedDayIndex === idx ? FontWeight.Bold : FontWeight.Normal)
              }.margin({ bottom: 4 })
              if (slot.iconDay !== '') {
                Image(getWeatherIconResource(slot.iconDay)).width(22).height(22).margin({ bottom: 2 })
              }
              Text(formatTempWithUnit(slot.tempMax, this.tempUnit)).fontSize(10).fontColor('rgba(255,255,255,0.65)')
              Text(formatTempWithUnit(slot.tempMin, this.tempUnit)).fontSize(10).fontColor('rgba(255,255,255,0.30)')
            }
            .alignItems(HorizontalAlign.Center).padding({ top: 6, bottom: 6, left: 8, right: 8 })
            .borderRadius(14).onClick(() => { this.selectedDayIndex = idx; this.redrawCharts() })
          })
        }.padding({ left: 4, right: 4 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      Text(this.getSelectedFullDate()).fontSize(12).fontColor('rgba(255,255,255,0.40)').margin({ top: 6, bottom: 4 })
    }.width('100%').padding({ top: 8, bottom: 4, left: 12, right: 12 })
  }

  private convertTemp(c: number): number { return this.tempUnit === '°F' ? c * 9 / 5 + 32 : c }

  private redrawCharts(): void {
    setTimeout(() => {
      this.drawTempChart()
      this.drawPrecipChart()
    }, 50)
  }

  private drawTempChart(): void {
    const pts = this.getEffectiveChartPoints()
    if (pts.length < 2) return
    pts.sort((a, b) => a.hour - b.hour)

    const w = this.chartWidth; const h = this.chartHeight
    if (w <= 0 || h <= 0) return

    const vals = pts.map(p => p.value)
    let minV = Math.min(...vals); let maxV = Math.max(...vals)
    const range = maxV - minV
    if (range < 2) { minV -= 1; maxV += 1 }
    else { minV -= range * 0.15; maxV += range * 0.15 }

    const pl = 48; const pr = 16; const pt = 24; const pb = 40
    const cw = w - pl - pr; const ch = h - pt - pb
    const toX = (hour: number) => pl + (cw / 24) * hour
    const toY = (v: number) => pt + ch - ((v - minV) / (maxV - minV)) * ch

    const ctx = this.ctx
    ctx.clearRect(0, 0, w, h)

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'; ctx.lineWidth = 0.5
    const ySteps = 4
    for (let i = 0; i <= ySteps; i++) {
      const y = pt + (ch / ySteps) * i
      ctx.beginPath(); ctx.moveTo(pl, y); ctx.lineTo(w - pr, y); ctx.stroke()
      ctx.fillStyle = 'rgba(255,255,255,0.55)'; ctx.font = '40px sans-serif'
      ctx.textAlign = 'end'
      ctx.fillText(`${Math.round(minV + ((maxV - minV) / ySteps) * (ySteps - i))}°`, pl - 6, y + 5)
    }

    const labelHours: number[] = [0, 6, 12, 18, 24]
    ctx.strokeStyle = 'rgba(255,255,255,0.12)'; ctx.lineWidth = 0.5
    ctx.setLineDash([4, 4])
    for (const lh of labelHours) {
      const lx = lh === 24 ? w - pr : toX(lh)
      ctx.beginPath()
      ctx.moveTo(lx, pt)
      ctx.lineTo(lx, pt + ch)
      ctx.stroke()
    }
    ctx.setLineDash([])

    ctx.fillStyle = 'rgba(255,255,255,0.50)'; ctx.font = '40px sans-serif'; ctx.textAlign = 'center'
    for (const lh of labelHours) {
      const lx = lh === 24 ? w - pr : toX(lh)
      ctx.fillText(`${lh}时`, lx, h - pb + 18)
    }
    ctx.textAlign = 'start'

    const lineToPoint = (idx: number): void => {
      ctx.lineTo(toX(pts[idx].hour), toY(pts[idx].value))
    }

    ctx.beginPath()
    ctx.moveTo(toX(pts[0].hour), pt + ch)
    for (let i = 0; i < pts.length; i++) lineToPoint(i)
    ctx.lineTo(toX(pts[pts.length - 1].hour), pt + ch); ctx.closePath()
    const grad = ctx.createLinearGradient(0, pt, 0, pt + ch)
    grad.addColorStop(0, 'rgba(255,159,67,0.35)'); grad.addColorStop(1, 'rgba(255,159,67,0.02)')
    ctx.fillStyle = grad; ctx.fill()

    ctx.strokeStyle = '#ff9f43'; ctx.lineWidth = 2; ctx.lineJoin = 'round'
    ctx.beginPath()
    ctx.moveTo(toX(pts[0].hour), toY(pts[0].value))
    for (let i = 1; i < pts.length; i++) lineToPoint(i)
    ctx.stroke()

    if (this.isToday()) {
      const now = new Date()
      const nowDecimal = now.getHours() + now.getMinutes() / 60
      if (nowDecimal >= 0 && nowDecimal <= 24) {
        const nowX = toX(nowDecimal)
        ctx.strokeStyle = 'rgba(255,255,255,0.35)'
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.moveTo(nowX, pt)
        ctx.lineTo(nowX, pt + ch)
        ctx.stroke()

        let nearestPt: ChartPoint | null = null
        let nearestDist = 999
        for (const p of pts) {
          const dist = Math.abs(p.hour - nowDecimal)
          if (dist < nearestDist) { nearestDist = dist; nearestPt = p }
        }
        if (nearestPt) {
          const nx = toX(nearestPt.hour)
          const ny = toY(nearestPt.value)
          ctx.fillStyle = '#ffffff'
          ctx.beginPath()
          ctx.arc(nx, ny, 6, 0, Math.PI * 2)
          ctx.fill()
          ctx.strokeStyle = '#ffffff'
          ctx.lineWidth = 2
          ctx.beginPath()
          ctx.arc(nx, ny, 6, 0, Math.PI * 2)
          ctx.stroke()
          ctx.fillStyle = 'rgba(255,255,255,0.85)'
          ctx.font = '40px sans-serif'
          ctx.textAlign = 'center'
          ctx.fillText(`${Math.round(nearestPt.value)}°`, nx, ny - 12)
          ctx.textAlign = 'start'
        }
      }
    }

    const xStepLabel = Math.max(1, Math.floor(pts.length / 6))
    for (let i = 0; i < pts.length; i += xStepLabel) {
      const x = toX(pts[i].hour); const y = toY(pts[i].value)
      ctx.fillStyle = '#FF9500'; ctx.beginPath(); ctx.arc(x, y, 4, 0, Math.PI * 2); ctx.fill()
      ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.font = '40px sans-serif'; ctx.textAlign = 'center'
      ctx.fillText(`${Math.round(pts[i].value)}°`, x, y - 10)
      ctx.textAlign = 'start'
    }
  }

  private drawPrecipChart(): void {
    const pts = this.getEffectivePrecipPoints()
    if (pts.length < 2) return
    pts.sort((a, b) => a.hour - b.hour)

    const w = this.precipChartWidth; const h = 110
    if (w <= 0) return

    const pl = 48; const pr = 16; const pt = 14; const pb = 36
    const cw = w - pl - pr; const ch = h - pt - pb
    const toX = (i: number) => pl + (cw / (pts.length - 1)) * i
    const toY = (v: number) => pt + ch - (v / 100) * ch

    const ctx = this.precipCtx
    ctx.clearRect(0, 0, w, h)

    ctx.strokeStyle = 'rgba(255,255,255,0.08)'; ctx.lineWidth = 0.5
    for (let i = 0; i <= 4; i++) {
      const y = pt + (ch / 4) * i
      ctx.beginPath(); ctx.moveTo(pl, y); ctx.lineTo(w - pr, y); ctx.stroke()
      ctx.fillStyle = 'rgba(255,255,255,0.45)'; ctx.font = '40px sans-serif'; ctx.textAlign = 'end'
      ctx.fillText(`${(4 - i) * 25}%`, pl - 6, y + 5)
    }

    ctx.fillStyle = 'rgba(255,255,255,0.45)'; ctx.font = '40px sans-serif'; ctx.textAlign = 'center'
    const xStep = Math.max(1, Math.floor(pts.length / 6))
    for (let i = 0; i < pts.length; i += xStep) { ctx.fillText(`${pts[i].hour}时`, toX(i), h - pb + 16) }
    ctx.textAlign = 'start'

    ctx.beginPath()
    ctx.moveTo(toX(0), pt + ch)
    for (let i = 0; i < pts.length; i++) ctx.lineTo(toX(i), toY(pts[i].pop))
    ctx.lineTo(toX(pts.length - 1), pt + ch); ctx.closePath()
    const pGrad = ctx.createLinearGradient(0, pt, 0, pt + ch)
    pGrad.addColorStop(0, 'rgba(10,132,255,0.30)'); pGrad.addColorStop(1, 'rgba(10,132,255,0.02)')
    ctx.fillStyle = pGrad; ctx.fill()

    ctx.strokeStyle = '#0A84FF'; ctx.lineWidth = 2
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) { if (i === 0) ctx.moveTo(toX(i), toY(pts[i].pop)); else ctx.lineTo(toX(i), toY(pts[i].pop)) }
    ctx.stroke()

    for (let i = 0; i < pts.length; i++) {
      const x = toX(i); const y = toY(pts[i].pop)
      ctx.fillStyle = '#0A84FF'; ctx.beginPath(); ctx.arc(x, y, 2.5, 0, Math.PI * 2); ctx.fill()
    }
  }

  private getFeelsLikeComparisonText(): string {
    const fl = this.payload.currentWeather ? parseFloat(this.payload.currentWeather.feelsLike) : NaN
    const ct = this.payload.currentWeather ? parseFloat(this.payload.currentWeather.temp) : NaN
    if (isNaN(fl) || isNaN(ct)) return ''
    const diff = fl - ct
    if (Math.abs(diff) < 1) return '体感与实际相近'
    return diff > 0 ? '体感温度更高' : '体感温度更低'
  }

  private getDisplayTemp(): string {
    if (this.isToday() && this.payload.currentWeather) {
      return formatTempWithUnit(this.payload.currentWeather.temp, this.tempUnit)
    }
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return formatTempWithUnit(fc.tempMax, this.tempUnit)
    }
    return '--'
  }

  private getDisplayFeelsLike(): string {
    if (this.payload.currentWeather) {
      return formatTempWithUnit(this.payload.currentWeather.feelsLike, this.tempUnit)
    }
    return '--'
  }

  build() {
    Column() {
      Row() {
        Text(this.payload.cityName || '温度趋势').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ffffff')
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
            Text(this.getDisplayTemp())
              .fontSize(48).fontWeight(FontWeight.Bold).fontColor('#ffffff')
            Column({ space: 4 }) {
              Text(`最高 ${formatTempWithUnit(this.getMaxTemp(), this.tempUnit)}`).fontSize(14).fontColor('#ff9f43')
              Text(`最低 ${formatTempWithUnit(this.getMinTemp(), this.tempUnit)}`).fontSize(14).fontColor('#5AC8FA')
            }.alignItems(HorizontalAlign.Start)
          }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })

          if (this.hasChartableData()) {
            Row({ space: 2 }) {
              ForEach(this.getEffectiveChartPoints(), (pt: ChartPoint) => {
                Image(getWeatherIconResource(pt.icon)).width(20).height(20).fillColor('#ffffff')
              })
            }.width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 40, right: 12, bottom: 2 })
          }

          if (this.hasChartableData()) {
            Canvas(this.ctx)
              .width('100%').height(220)
              .onAreaChange((_old: Area, nv: Area) => {
                const nw = nv.width as number; const nh = nv.height as number
                if (nw > 0) this.chartWidth = nw; if (nh > 0) this.chartHeight = nh
              })
              .onReady(() => { this.drawTempChart() })
          }

          if (this.isToday()) {
            Column({ space: 8 }) {
              Row({ space: 16 }) {
                Text(this.getDisplayFeelsLike())
                  .fontSize(42).fontWeight(FontWeight.Bold).fontColor('#FF9500')
                Column({ space: 4 }) {
                  Text('体感温度').fontSize(13).fontColor('rgba(255,255,255,0.40)')
                  Text(this.getFeelsLikeComparisonText()).fontSize(12).fontColor('#FF9500')
                }.alignItems(HorizontalAlign.Start)
              }.width('100%').padding({ left: 16, right: 16, bottom: 8 })

              Text('体感温度数据来自实时气象观测').fontSize(12).fontColor('rgba(255,255,255,0.30)').textAlign(TextAlign.Center)
                .padding({ left: 16, right: 16, bottom: 8 })
            }.width('100%').padding(14).backgroundColor('rgba(255,255,255,0.04)').borderRadius(14).margin({ top: 12, left: 12, right: 12 })
          }

          if (this.hasChartableData()) {
            Column() {
              Text('降水概率').fontSize(14).fontColor('rgba(255,255,255,0.50)').margin({ bottom: 6 })
              Canvas(this.precipCtx)
                .width('100%').height(110)
                .onAreaChange((_old: Area, nv: Area) => {
                  const nw = nv.width as number
                  if (nw > 0) this.precipChartWidth = nw
                })
                .onReady(() => { this.drawPrecipChart() })
              Row() {
                 Text(`${this.isToday() ? '当日' : '该日'}降水概率最高 ${this.getMaxPop()}%`).fontSize(13).fontColor('#0A84FF')
              }.width('100%').padding({ top: 4 })
            }
            .width('100%').padding(14)
            .backgroundColor('rgba(255,255,255,0.05)').borderRadius(14)
            .margin({ top: 16, left: 12, right: 12 })
          }

          Column({ space: 4 }) {
            Text('摘要').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text(`${this.isToday() ? '当日' : '该日'}最高温度${formatTempWithUnit(this.getMaxTemp(), this.tempUnit)}，最低温度${formatTempWithUnit(this.getMinTemp(), this.tempUnit)}。`)
              .fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)').borderRadius(14).margin({ top: 12, left: 12, right: 12 })

          if (!this.hasChartableData()) {
            Column({ space: 8 }) {
              Text(`${this.getSelectedDate()}`).fontSize(14).fontColor('rgba(255,255,255,0.40)')
              Text('暂无该日天气数据').fontSize(13).fontColor('rgba(255,255,255,0.30)')
            }.width('100%').padding({ top: 30, bottom: 30 }).alignItems(HorizontalAlign.Center)
          } else if (!this.isToday()) {
            Column({ space: 4 }) {
              Text('该日图表基于日间预报数据生成，实际逐小时数据仅当日可用').fontSize(11).fontColor('rgba(255,255,255,0.25)')
            }.width('100%').padding({ left: 16, right: 16, top: 4, bottom: 8 })
          }

          Blank().height(40)
        }.width('100%')
      }.scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off).layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('94%')
    .backgroundColor('#1C1C1E')
    .borderRadius({ topLeft: 20, topRight: 20 }).padding({ bottom: 16 })
  }

  private getMaxTemp(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) return fc.tempMax
    const hourly = this.getFilteredHourly()
    if (hourly.length === 0) return this.payload.currentWeather?.temp ?? '--'
    let max = -999
    for (const item of hourly) { const t = parseFloat(item.temp); if (!isNaN(t) && t > max) max = t }
    return max > -999 ? `${max}` : '--'
  }

  private getMinTemp(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) return fc.tempMin
    const hourly = this.getFilteredHourly()
    if (hourly.length === 0) return this.payload.currentWeather?.temp ?? '--'
    let min = 999
    for (const item of hourly) { const t = parseFloat(item.temp); if (!isNaN(t) && t < min) min = t }
    return min < 999 ? `${min}` : '--'
  }

  private getMaxPop(): string {
    let max = 0
    const pts = this.getEffectivePrecipPoints()
    for (const p of pts) { if (p.pop > max) max = p.pop }
    return `${Math.round(max)}`
  }
}
