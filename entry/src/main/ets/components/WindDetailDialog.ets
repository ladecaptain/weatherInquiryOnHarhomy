import { formatDate, getDayLabel, getWeatherIconResource } from '../utils/WeatherUtils'
import { HourlyForecastItem, ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface DaySlot {
  dateStr: string; label: string; monthDay: string; dayNum: number
  iconDay: string; tempMax: string; tempMin: string; isToday: boolean
}

class WindPoint {
  hour: number = 0
  speed: number = 0
  dir: string = ''
  wind360: number = 0
  constructor(hour: number, speed: number, dir: string, wind360: number = 0) {
    this.hour = hour; this.speed = speed; this.dir = dir; this.wind360 = wind360
  }
}

interface WindHistoryPoint {
  deg: number
  speed: number
}

@CustomDialog
export struct WindDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload
  @State @Watch('onDayChanged') selectedDayIndex: number = 1
  @StorageProp('tempUnit') tempUnit: string = '°C'

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @State chartWidth: number = 300
  @State chartHeight: number = 420

  private compassSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private compassCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.compassSettings)
  @State compassSize: number = 260

  onDayChanged(): void {
    setTimeout(() => { this.drawWindChart() }, 50)
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
              Text(`${slot.tempMax}°`).fontSize(10).fontColor('rgba(255,255,255,0.65)')
              Text(`${slot.tempMin}°`).fontSize(10).fontColor('rgba(255,255,255,0.30)')
            }
            .alignItems(HorizontalAlign.Center).padding({ top: 6, bottom: 6, left: 8, right: 8 })
            .borderRadius(14).onClick(() => { this.selectedDayIndex = idx })
          })
        }.padding({ left: 4, right: 4 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      Text(this.getSelectedFullDate()).fontSize(12).fontColor('rgba(255,255,255,0.40)').margin({ top: 6, bottom: 4 })
    }.width('100%').padding({ top: 8, bottom: 4, left: 12, right: 12 })
  }

  private getSelectedFullDate(): string {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const d = new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000)
    const weekdays = ['日', '一', '二', '三', '四', '五', '六']
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 星期${weekdays[d.getDay()]}`
  }

  private getEffectiveWindData(): WindPoint[] {
    const hourly = this.getFilteredHourly()
    if (hourly.length >= 2) {
      const pts: WindPoint[] = []
      for (const item of hourly) {
        const s = parseFloat(item.windSpeed)
        const d = parseFloat(item.wind360)
        if (!isNaN(s)) pts.push(new WindPoint(new Date(item.fxTime).getHours(), s, item.windDir, isNaN(d) ? 0 : d))
      }
      if (pts.length >= 2) return pts
    }
    const fc = this.getSelectedDayForecast()
    if (!fc) return []
    const daySpeed = parseFloat(fc.windSpeedDay)
    const nightSpeed = parseFloat(fc.windSpeedNight)
    if (isNaN(daySpeed) && isNaN(nightSpeed)) return []
    const pts: WindPoint[] = []
    for (let hour = 0; hour < 24; hour++) {
      const isDay = hour >= 6 && hour < 18
      const speed = isDay ? (isNaN(daySpeed) ? 0 : daySpeed) : (isNaN(nightSpeed) ? 0 : nightSpeed)
      const dir = isDay ? fc.windDirDay : fc.windDirNight
      const w360 = isDay ? parseFloat(fc.wind360Day) : parseFloat(fc.wind360Night)
      pts.push(new WindPoint(hour, Math.round(speed), dir || '--', isNaN(w360) ? 0 : w360))
    }
    return pts
  }

  private drawWindChart(): void {
    const pts = this.getEffectiveWindData()
    if (pts.length < 2) return

    const w = this.chartWidth; const h = this.chartHeight
    if (w <= 0 || h <= 0) return

    const speeds = pts.map(p => p.speed)
    let minS = Math.min(...speeds) - 2; let maxS = Math.max(...speeds) * 1.6 + 2
    if (maxS - minS < 6) { maxS = minS + 6 }

    const pl = 52; const pr = 20; const pt = 28; const pb = 56
    const cw = w - pl - pr; const ch = h - pt - pb
    const toX = (i: number) => pl + (cw / (pts.length - 1)) * i
    const toY = (v: number) => pt + ch - ((v - minS) / (maxS - minS)) * ch

    const ctx = this.ctx
    ctx.clearRect(0, 0, w, h)

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'; ctx.lineWidth = 1
    for (let i = 0; i <= 4; i++) {
      const y = pt + (ch / 4) * i
      ctx.beginPath(); ctx.moveTo(pl, y); ctx.lineTo(w - pr, y); ctx.stroke()
      ctx.fillStyle = 'rgba(255,255,255,0.55)'; ctx.font = '28px sans-serif'; ctx.textAlign = 'end'
      ctx.fillText(`${Math.round(minS + ((maxS - minS) / 4) * (4 - i))}`, pl - 6, y + 10)
    }

    ctx.fillStyle = 'rgba(255,255,255,0.50)'; ctx.font = '26px sans-serif'; ctx.textAlign = 'center'
    const xs = Math.max(1, Math.floor(pts.length / 6))
    for (let i = 0; i < pts.length; i += xs) { ctx.fillText(`${pts[i].hour}`, toX(i), h - pb + 22) }
    ctx.textAlign = 'start'

    ctx.beginPath(); ctx.moveTo(toX(0), pt + ch)
    for (let i = 0; i < pts.length; i++) ctx.lineTo(toX(i), toY(pts[i].speed))
    ctx.lineTo(toX(pts.length - 1), pt + ch); ctx.closePath()
    const grad = ctx.createLinearGradient(0, pt, 0, pt + ch)
    grad.addColorStop(0, 'rgba(90,200,250,0.40)'); grad.addColorStop(1, 'rgba(90,200,250,0.02)')
    ctx.fillStyle = grad; ctx.fill()

    ctx.strokeStyle = '#5AC8FA'; ctx.lineWidth = 4; ctx.lineJoin = 'round'
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) { if (i === 0) ctx.moveTo(toX(i), toY(pts[i].speed)); else ctx.lineTo(toX(i), toY(pts[i].speed)) }
    ctx.stroke()

    ctx.strokeStyle = 'rgba(90,200,250,0.6)'; ctx.lineWidth = 2; ctx.setLineDash([8, 4])
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) {
      const gustSpeed = pts[i].speed * 1.6
      if (i === 0) ctx.moveTo(toX(i), toY(gustSpeed)); else ctx.lineTo(toX(i), toY(gustSpeed))
    }
    ctx.stroke()
    ctx.setLineDash([])

    const xStepLabel = Math.max(1, Math.floor(pts.length / 8))
    for (let i = 0; i < pts.length; i += xStepLabel) {
      const x = toX(i); const y = toY(pts[i].speed)
      ctx.fillStyle = '#5AC8FA'; ctx.beginPath(); ctx.arc(x, y, 6, 0, Math.PI * 2); ctx.fill()
      ctx.fillStyle = 'rgba(255,255,255,0.85)'; ctx.font = '28px sans-serif'; ctx.textAlign = 'center'
      ctx.fillText(`${pts[i].speed}`, x, y - 14)
      ctx.textAlign = 'start'
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.payload.cityName || '风力详情').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ffffff')
        Blank()
        Button() { Image($r('sys.media.ohos_ic_public_close')).width(22).height(22).fillColor('#ffffff') }
        .width(38).height(38).backgroundColor('rgba(255,255,255,0.10)').borderRadius(19)
        .onClick(() => this.controller.close())
      }.width('100%').padding({ left: 16, right: 8, top: 10, bottom: 2 })

      this.CalendarStrip()
      Divider().color('rgba(255,255,255,0.06)').width('90%')

      Scroll() {
        Column() {
          Column() {
            Canvas(this.compassCtx)
              .width(280).height(280)
              .onReady(() => { this.drawCompass() })
          }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 12, bottom: 4 })

          Column() {
            Text(this.payload.currentWeather?.windDir || '--')
              .fontSize(14).fontColor('rgba(255,255,255,0.55)')
            Text(`阵风: ${this.getMaxGust()} km/h`)
              .fontSize(12).fontColor('rgba(255,255,255,0.30)')
          }.width('100%').alignItems(HorizontalAlign.Center).padding({ top: 0, bottom: 12 })

          if (this.getEffectiveWindData().length >= 2) {
            Canvas(this.ctx)
              .width('100%').height(400)
              .onAreaChange((_old: Area, nv: Area) => { const nw = nv.width as number; const nh = nv.height as number; if (nw > 0) this.chartWidth = nw; if (nh > 0) this.chartHeight = nh })
              .onReady(() => { this.drawWindChart() })
          }

          Column({ space: 4 }) {
            Text('每日摘要').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text(this.getWindSummary()).fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
            Row({ space: 8 }) {
              Text('查看天气地图').fontSize(12).fontColor('#6db3f2')
              Image($r('sys.media.ohos_ic_public_arrow_right')).width(14).height(14).fillColor('#6db3f2')
            }.margin({ top: 8 })
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 16, left: 12, right: 12 })

          if (this.getEffectiveWindData().length < 2) {
            Column({ space: 8 }) {
              Text(`${this.getSelectedDate()}`).fontSize(14).fontColor('rgba(255,255,255,0.40)')
              Text('暂无该日逐小时风力数据（仅当天支持逐小时图表）').fontSize(13).fontColor('rgba(255,255,255,0.30)')
              if (this.getSelectedDayForecast() !== null) {
                Row({ space: 24 }) {
                  Column() {
                    Text('白天').fontSize(11).fontColor('rgba(255,255,255,0.30)')
                    Text(this.getSelectedDayForecast()!.windDirDay || '--').fontSize(14).fontColor('#5AC8FA').margin({ top: 2 })
                    Text(`${this.getSelectedDayForecast()!.windSpeedDay || '--'} km/h`).fontSize(12).fontColor('rgba(255,255,255,0.50)').margin({ top: 2 })
                  }.alignItems(HorizontalAlign.Center)
                  Column() {
                    Text('夜间').fontSize(11).fontColor('rgba(255,255,255,0.30)')
                    Text(this.getSelectedDayForecast()!.windDirNight || '--').fontSize(14).fontColor('#5AC8FA').margin({ top: 2 })
                    Text(`${this.getSelectedDayForecast()!.windSpeedNight || '--'} km/h`).fontSize(12).fontColor('rgba(255,255,255,0.50)').margin({ top: 2 })
                  }.alignItems(HorizontalAlign.Center)
                }.margin({ top: 8 })
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

  private getCurrentWind360(): number {
    const d = parseFloat(this.payload.currentWeather?.wind360 || '0')
    return isNaN(d) ? 0 : d
  }

  private drawCompass(): void {
    const w = 280; const h = 280
    const cx = w / 2; const cy = h / 2
    const outerR = 130
    const innerR = 68
    const midR = 108

    const degToCanvasRad = (deg: number): number => {
      return ((deg + 270) % 360) * Math.PI / 180
    }

    const ctx = this.compassCtx
    ctx.clearRect(0, 0, w, h)

    const filtered = this.getFilteredHourly()
    const historical: WindHistoryPoint[] = []
    if (filtered.length > 0) {
      for (const item of filtered) {
        const d = parseFloat(item.wind360)
        const s = parseFloat(item.windSpeed)
        if (!isNaN(d)) {
          const pt: WindHistoryPoint = { deg: d, speed: isNaN(s) ? 0 : s }
          historical.push(pt)
        }
      }
    }

    const maxHistSpeed = historical.length > 0
      ? Math.max(...historical.map(v => v.speed), 1)
      : 1

    const currentWind360 = this.getCurrentWind360()
    const arrowCompassDeg = (currentWind360 + 180) % 360
    const arrowRad = degToCanvasRad(arrowCompassDeg)

    const currentSpeed = parseFloat(this.payload.currentWeather?.windSpeed || '0')
    const speedNorm = Math.min(isNaN(currentSpeed) ? 0 : currentSpeed / 30, 1)

    // Outer glow ring
    for (let r = 0; r < 3; r++) {
      ctx.beginPath()
      ctx.arc(cx, cy, outerR + 8 + r, 0, Math.PI * 2)
      ctx.strokeStyle = `rgba(90,200,250,${(0.05 - r * 0.01).toFixed(2)})`
      ctx.lineWidth = 2
      ctx.stroke()
    }

    // Outer ring
    ctx.beginPath()
    ctx.arc(cx, cy, outerR, 0, Math.PI * 2)
    ctx.strokeStyle = 'rgba(255,255,255,0.14)'
    ctx.lineWidth = 2
    ctx.stroke()

    // Tick marks every 5° with major at 45°
    for (let deg = 0; deg < 360; deg += 5) {
      const rad = degToCanvasRad(deg)
      const isMajor = deg % 45 === 0
      const isHalf = deg % 15 === 0 || deg % 10 === 0
      const tickOuter = outerR - 2
      let tickInner: number
      if (isMajor) {
        tickInner = outerR - 16
      } else if (deg % 15 === 0) {
        tickInner = outerR - 10
      } else {
        tickInner = outerR - 6
      }
      ctx.beginPath()
      ctx.moveTo(cx + tickInner * Math.cos(rad), cy + tickInner * Math.sin(rad))
      ctx.lineTo(cx + tickOuter * Math.cos(rad), cy + tickOuter * Math.sin(rad))
      ctx.strokeStyle = isMajor
        ? 'rgba(255,255,255,0.55)'
        : (deg % 15 === 0 ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.10)')
      ctx.lineWidth = isMajor ? 1.5 : 0.8
      ctx.stroke()
    }

    // Cardinal direction labels
    const directions: [string, number][] = [
      ['北', 0], ['东北', 45], ['东', 90], ['东南', 135],
      ['南', 180], ['西南', 225], ['西', 270], ['西北', 315]
    ]
    for (const dirItem of directions) {
      const label = dirItem[0]
      const deg = dirItem[1]
      const rad = degToCanvasRad(deg)
      const lx = cx + (outerR - 26) * Math.cos(rad)
      const ly = cy + (outerR - 26) * Math.sin(rad)
      const isCardinal = deg % 90 === 0
      ctx.fillStyle = isCardinal ? 'rgba(255,255,255,0.80)' : 'rgba(255,255,255,0.45)'
      ctx.font = isCardinal ? 'bold 15px sans-serif' : '12px sans-serif'
      ctx.textAlign = 'center'
      const lyOff = ly + (isCardinal ? 5 : 4)
      ctx.fillText(label, lx, lyOff)
    }

    // Mid ring
    ctx.beginPath()
    ctx.arc(cx, cy, midR, 0, Math.PI * 2)
    ctx.strokeStyle = 'rgba(255,255,255,0.07)'
    ctx.lineWidth = 1
    ctx.setLineDash([3, 6])
    ctx.stroke()
    ctx.setLineDash([])

    // Historical direction trail arcs
    if (historical.length > 0) {
      const total = historical.length
      for (let i = 0; i < total; i++) {
        const pt = historical[i]
        const deg = pt.deg
        const speed = pt.speed
        const dotRad = degToCanvasRad((deg + 180) % 360)
        const distR = midR - 3 + (speed / maxHistSpeed) * 6
        const dx = cx + distR * Math.cos(dotRad)
        const dy = cy + distR * Math.sin(dotRad)
        const alpha = 0.12 + (i / total) * 0.55
        const size = 2.2 + (speed / maxHistSpeed) * 2.2
        ctx.beginPath()
        ctx.arc(dx, dy, size, 0, Math.PI * 2)
        ctx.fillStyle = `rgba(90,200,250,${alpha.toFixed(2)})`
        ctx.fill()
      }
    }

    // Inner decorative ring
    ctx.beginPath()
    ctx.arc(cx, cy, innerR + 10, 0, Math.PI * 2)
    ctx.strokeStyle = 'rgba(90,200,250,0.12)'
    ctx.lineWidth = 1
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(cx, cy, innerR, 0, Math.PI * 2)
    ctx.strokeStyle = 'rgba(255,255,255,0.10)'
    ctx.lineWidth = 1
    ctx.stroke()

    // Wind direction arrow
    const arrowLen = 55 + speedNorm * 10
    const baseHW = 6
    const tipHW = 3
    const headLen = 14
    const headHW = 15

    const ax = cx + arrowLen * Math.cos(arrowRad)
    const ay = cy + arrowLen * Math.sin(arrowRad)
    const perp = arrowRad + Math.PI / 2

    const bx1 = cx + baseHW * Math.cos(perp)
    const by1 = cy + baseHW * Math.sin(perp)
    const bx2 = cx - baseHW * Math.cos(perp)
    const by2 = cy - baseHW * Math.sin(perp)

    const sx = ax - headLen * Math.cos(arrowRad)
    const sy = ay - headLen * Math.sin(arrowRad)
    const sx1 = sx + tipHW * Math.cos(perp)
    const sy1 = sy + tipHW * Math.sin(perp)
    const sx2 = sx - tipHW * Math.cos(perp)
    const sy2 = sy - tipHW * Math.sin(perp)

    const arrowGrad = ctx.createLinearGradient(cx, cy, ax, ay)
    arrowGrad.addColorStop(0, 'rgba(90,200,250,0.30)')
    arrowGrad.addColorStop(0.5, '#5AC8FA')
    arrowGrad.addColorStop(1, '#2eaadc')

    ctx.beginPath()
    ctx.moveTo(bx1, by1)
    ctx.lineTo(sx1, sy1)
    ctx.lineTo(ax, ay)
    ctx.lineTo(sx2, sy2)
    ctx.lineTo(bx2, by2)
    ctx.closePath()
    ctx.fillStyle = arrowGrad
    ctx.fill()

    ctx.beginPath()
    ctx.moveTo(ax, ay)
    const hlX = sx + headHW * Math.cos(perp)
    const hlY = sy + headHW * Math.sin(perp)
    const hrX = sx - headHW * Math.cos(perp)
    const hrY = sy - headHW * Math.sin(perp)
    ctx.lineTo(hlX, hlY)
    ctx.lineTo(hrX, hrY)
    ctx.closePath()
    ctx.fillStyle = '#2eaadc'
    ctx.fill()

    // Center disc
    const ctrGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, 42)
    ctrGrad.addColorStop(0, '#1C1C1E')
    ctrGrad.addColorStop(1, 'rgba(28,28,30,0.82)')
    ctx.beginPath()
    ctx.arc(cx, cy, 42, 0, Math.PI * 2)
    ctx.fillStyle = ctrGrad
    ctx.fill()

    ctx.beginPath()
    ctx.arc(cx, cy, 42, 0, Math.PI * 2)
    ctx.strokeStyle = 'rgba(255,255,255,0.10)'
    ctx.lineWidth = 1
    ctx.stroke()

    // Center speed text
    const speedText = Math.round(isNaN(currentSpeed) ? 0 : currentSpeed).toString()
    ctx.fillStyle = '#ffffff'
    ctx.font = 'bold 30px sans-serif'
    ctx.textAlign = 'center'
    ctx.fillText(speedText, cx, cy - 8)

    ctx.fillStyle = 'rgba(255,255,255,0.40)'
    ctx.font = '14px sans-serif'
    ctx.fillText('km/h', cx, cy + 18)
  }

  private getWindSummary(): string {
    const pts = this.getEffectiveWindData()
    if (pts.length >= 2) {
      let max = 0; let min = 999
      for (const p of pts) { if (p.speed > max) max = p.speed; if (p.speed < min) min = p.speed }
      const gust = Math.round(max * 1.6)
      return `风速范围为${min}至${max} km/h，阵风最高可达${gust} km/h。`
    }
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return `白天 ${fc.windDirDay || '--'} ${fc.windSpeedDay || '--'} km/h，夜间 ${fc.windDirNight || '--'} ${fc.windSpeedNight || '--'} km/h。`
    }
    return '暂无数据'
  }

  private getMaxGust(): string {
    const cur = this.payload.currentWeather
    if (cur && cur.windSpeed) {
      const gust = parseFloat(cur.windSpeed) * 1.6
      return isNaN(gust) ? (cur.windSpeed || '--') : `${Math.round(gust)}`
    }
    return '--'
  }
}
