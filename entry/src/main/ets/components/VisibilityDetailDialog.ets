/**
 * 能见度详情弹窗
 * 基于每日预报数据展示能见度 & 每日比较
 */
import { formatDate, getDayLabel } from '../utils/WeatherUtils'
import { ForecastDay } from '../model/WeatherModel'
import { DetailPayload } from './DetailDialogs'

interface DaySlot {
  dateStr: string; label: string; monthDay: string; vis: string; isToday: boolean
}

class VisPoint {
  dayLabel: string = ''
  vis: number = 0
  constructor(dayLabel: string, vis: number) {
    this.dayLabel = dayLabel; this.vis = vis
  }
}

@CustomDialog
export struct VisibilityDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload
  @State @Watch('onDayChanged') selectedDayIndex: number = 1

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @State chartWidth: number = 300
  @State chartHeight: number = 200

  onDayChanged(): void {
    setTimeout(() => { this.drawVisChart() }, 50)
  }

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
        vis: fc ? fc.vis : '--', isToday: i === 0
      })
    }
    return slots
  }

  private getVisChartData(): VisPoint[] {
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    const pts: VisPoint[] = []
    const count = Math.min(all.length, 7)
    for (let i = 0; i < count; i++) {
      const fc = all[i]
      const v = Number(fc.vis)
      if (!isNaN(v) && v >= 0) {
        pts.push(new VisPoint(getDayLabel(fc.fxDate), v))
      }
    }
    return pts
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
                Text(`${new Date(slot.dateStr).getDate()}`).fontSize(11)
                  .fontColor(this.selectedDayIndex === idx ? '#ffffff' : 'rgba(255,255,255,0.50)')
                  .fontWeight(this.selectedDayIndex === idx ? FontWeight.Bold : FontWeight.Normal)
              }.width(30).height(30).alignContent(Alignment.Center).margin({ bottom: 4 })
              Text(slot.vis && slot.vis.length > 0 && slot.vis !== '--' ? `${slot.vis}km` : '--').fontSize(10)
                .fontColor(slot.vis !== '--' ? this.getVisColor(Number(slot.vis)) : 'rgba(255,255,255,0.25)')
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

  private drawVisChart(): void {
    const pts = this.getVisChartData()
    if (pts.length < 2) return

    const w = this.chartWidth; const h = this.chartHeight
    if (w <= 0 || h <= 0) return

    const vals = pts.map(p => p.vis)
    let minV = Math.min(...vals); let maxV = Math.max(...vals)
    const range = maxV - minV
    if (range < 5) { minV = Math.max(0, minV - 3); maxV = maxV + 3 }
    else { minV = Math.max(0, minV - range * 0.15); maxV = maxV + range * 0.15 }

    const pl = 44; const pr = 20; const pt = 20; const pb = 36
    const cw = w - pl - pr; const ch = h - pt - pb
    const toX = (i: number) => pl + (cw / (pts.length - 1)) * i
    const toY = (v: number) => pt + ch - ((v - minV) / (maxV - minV)) * ch

    const ctx = this.ctx
    ctx.clearRect(0, 0, w, h)

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'; ctx.lineWidth = 1
    const ys = 4
    for (let i = 0; i <= ys; i++) {
      const y = pt + (ch / ys) * i
      ctx.beginPath(); ctx.moveTo(pl, y); ctx.lineTo(w - pr, y); ctx.stroke()
      ctx.fillStyle = 'rgba(255,255,255,0.40)'; ctx.font = '20px sans-serif'; ctx.textAlign = 'end'
      ctx.fillText(`${Math.round(minV + ((maxV - minV) / ys) * (ys - i))}`, pl - 6, y + 7)
    }

    ctx.fillStyle = 'rgba(255,255,255,0.40)'; ctx.font = '20px sans-serif'; ctx.textAlign = 'center'
    for (let i = 0; i < pts.length; i++) { ctx.fillText(pts[i].dayLabel, toX(i), h - pb + 18) }
    ctx.textAlign = 'start'

    ctx.beginPath()
    ctx.moveTo(toX(0), pt + ch)
    for (let i = 0; i < pts.length; i++) ctx.lineTo(toX(i), toY(pts[i].vis))
    ctx.lineTo(toX(pts.length - 1), pt + ch); ctx.closePath()
    const grad = ctx.createLinearGradient(0, pt, 0, pt + ch)
    grad.addColorStop(0, 'rgba(255,255,255,0.10)')
    grad.addColorStop(1, 'rgba(255,255,255,0.01)')
    ctx.fillStyle = grad; ctx.fill()

    ctx.strokeStyle = 'rgba(255,255,255,0.60)'; ctx.lineWidth = 2; ctx.lineJoin = 'round'
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) {
      if (i === 0) ctx.moveTo(toX(i), toY(pts[i].vis))
      else ctx.lineTo(toX(i), toY(pts[i].vis))
    }
    ctx.stroke()
  }

  getVisColor(vis: number): string {
    if (isNaN(vis)) return 'rgba(255,255,255,0.25)'
    if (vis >= 20) return '#00e676'; if (vis >= 10) return '#ffd600'
    if (vis >= 5) return '#ff9100'; if (vis >= 1) return '#ff5252'; return '#d500f9'
  }

  getVisLevel(vis: number): string {
    if (isNaN(vis)) return ''
    if (vis >= 20) return '非常好'; if (vis >= 10) return '良好'
    if (vis >= 5) return '一般'; if (vis >= 1) return '较差'; return '很差'
  }

  private getVisVal(): number {
    const fc = this.getSelectedForecast()
    const curVis = this.payload.currentWeather?.vis
    const visVal = fc ? Number(fc.vis) : (curVis ? Number(curVis) : NaN)
    return visVal
  }

  private getVisDisplayColor(): string {
    return this.getVisColor(this.getVisVal())
  }

  private getVisDisplayLevel(): string {
    return this.getVisLevel(this.getVisVal())
  }

  build() {
    Column() {
      Row() {
        Text('能见度').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#ffffff')
        Blank()
        Button() { Image($r('sys.media.ohos_ic_public_close')).width(22).height(22).fillColor('#ffffff') }
        .width(38).height(38).backgroundColor('rgba(255,255,255,0.10)').borderRadius(19)
        .onClick(() => this.controller.close())
      }.width('100%').padding({ left: 16, right: 8, top: 10, bottom: 2 })

      this.CalendarStrip()
      Divider().color('rgba(255,255,255,0.06)').width('90%')

      Scroll() {
        Column() {
          Column({ space: 6 }) {
            Text(`${isNaN(this.getVisVal()) ? '--' : `${this.getVisVal()}`} 公里`)
              .fontSize(42).fontWeight(FontWeight.Bold).fontColor(this.getVisDisplayColor())
            Text(isNaN(this.getVisVal()) ? '无数据' : this.getVisDisplayLevel())
              .fontSize(16).fontColor(this.getVisDisplayColor())
          }.width('100%').padding(20).alignItems(HorizontalAlign.Center)

          if (this.getSelectedForecast() !== null && !isNaN(this.getVisVal())) {
            Column() {
              Row() { Text('0').fontSize(10).fontColor('#d500f9')
                Blank(); Text('5').fontSize(10).fontColor('#ff5252')
                Blank(); Text('10').fontSize(10).fontColor('#ff9100')
                Blank(); Text('15').fontSize(10).fontColor('#ffd600')
                Blank(); Text('30+').fontSize(10).fontColor('#00e676')
              }.width('100%').padding({ left: 4, right: 4 })

              Stack() {
                Row().width('100%').height(10).borderRadius(5)
                  .linearGradient({ direction: GradientDirection.Right, colors: [['#d500f9', 0], ['#ff5252', 0.15], ['#ff9100', 0.3], ['#ffd600', 0.5], ['#00e676', 1]] })
                Circle().width(14).height(14).fill(this.getVisDisplayColor()).stroke(Color.White).strokeWidth(2)
                  .position({ x: `${Math.min(this.getVisVal() / 30 * 100, 100)}%`, y: -2 }).translate({ x: -7 })
              }.width('100%').height(14).margin({ top: 4, bottom: 4 })
            }.width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
          }

          if (this.getVisChartData().length >= 2) {
            Column() {
              Text('每日能见度趋势').fontSize(13).fontColor('rgba(255,255,255,0.40)')
                .margin({ bottom: 6 }).alignSelf(ItemAlign.Start)
              Canvas(this.ctx)
                .width('100%').height(180)
                .onAreaChange((_old: Area, nv: Area) => {
                  const nw = nv.width as number; const nh = nv.height as number
                  if (nw > 0) this.chartWidth = nw; if (nh > 0) this.chartHeight = nh
                })
                .onReady(() => { this.drawVisChart() })
            }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 8 })
              .backgroundColor('rgba(255,255,255,0.04)').borderRadius(14)
              .margin({ top: 10, left: 12, right: 12 })
          }

          Column({ space: 4 }) {
            Text('每日摘要').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text(this.getVisSummary()).fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 14, left: 12, right: 12 })

          Column({ space: 4 }) {
            Text('每日比较').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text(this.getVisComparison()).fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(14).margin({ top: 10, left: 12, right: 12 })

          if (!this.getSelectedForecast() && !this.payload.currentWeather?.vis) {
            Text('暂无该日能见度数据').fontSize(14).fontColor('rgba(255,255,255,0.30)').padding({ top: 40, bottom: 40 })
          }

          Blank().height(40)
        }.width('100%')
      }.scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off).layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('94%')
    .backgroundColor('#1C1C1E')
    .borderRadius({ topLeft: 20, topRight: 20 }).padding({ bottom: 16 })
  }

  private getVisSummary(): string {
    const fc = this.getSelectedForecast()
    if (!fc) {
      const cur = this.payload.currentWeather
      return cur ? `当前能见度为${cur.vis}km，${this.getVisLevel(Number(cur.vis))}。` : '暂无能见度数据。'
    }
    const v = Number(fc.vis)
    if (isNaN(v)) return '暂无能见度数据。'
    return `当日能见度等级为${this.getVisLevel(v)}（${v}公里）。`
  }

  private getVisComparison(): string {
    const fc = this.getSelectedForecast()
    if (!fc) return '暂无比较数据。'
    const v = Number(fc.vis)
    if (isNaN(v)) return '暂无比较数据。'
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    const idx = all.findIndex((f: ForecastDay) => f.fxDate === fc.fxDate)
    if (idx > 0) {
      const pv = Number(all[idx - 1].vis)
      if (!isNaN(pv)) {
        if (v > pv) return '今天能见度比昨天好。'
        if (v < pv) return '今天能见度比昨天差。'
        return '今天能见度与昨天类似。'
      }
    }
    return `今日能见度：${v}km。`
  }
}
