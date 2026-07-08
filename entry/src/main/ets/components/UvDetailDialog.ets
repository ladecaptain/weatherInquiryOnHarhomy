/**
 * 紫外线详情弹窗
 * 展示当前紫外线指数 + 逐时 UV 面积图 + 防护建议 + 逐日 UV
 */
import { DetailPayload } from './DetailDialogs'
import { ForecastDay } from '../model/WeatherModel'
import { formatDate, getDayLabel, getWeatherIconResource } from '../utils/WeatherUtils'

interface UvDayItem {
  label: string
  dateStr: string
  uvValue: string
  uvColor: string
  uvLevel: string
  isToday: boolean
}

interface DaySlot {
  dateStr: string
  label: string
  monthDay: string
  iconDay: string
  tempMax: string
  tempMin: string
  isToday: boolean
}

class UvHourPoint {
  hour: number = 0
  uv: number = 0
  constructor(hour: number, uv: number) {
    this.hour = hour
    this.uv = uv
  }
}

@CustomDialog
export struct UvDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload
  @State @Watch('onDayChanged') selectedDayIndex: number = 1

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @State chartWidth: number = 300
  @State chartHeight: number = 360

  onDayChanged(): void {
    setTimeout(() => { this.drawUvChart() }, 50)
  }

  private getCurrentUv(): number {
    const days = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    if (days.length === 0) return 0
    const sel = this.getSelectedDate()
    for (const d of days) {
      if (d.fxDate === sel) return Number(d.uvIndex) || 0
    }
    return 0
  }

  private getUvColor(uv: number): string {
    if (uv <= 2) return '#00e676'
    if (uv <= 5) return '#ffd600'
    if (uv <= 7) return '#ff9100'
    if (uv <= 10) return '#ff5252'
    return '#d500f9'
  }

  private getUvLevel(uv: number): string {
    if (uv <= 2) return '最弱'
    if (uv <= 5) return '中等'
    if (uv <= 7) return '较强'
    if (uv <= 10) return '很强'
    return '极强'
  }

  private getAdvice(uv: number): string {
    if (uv <= 2) return '无需特殊防护。可放心享受户外时光。'
    if (uv <= 5) return '涂抹 SPF15+ 防晒霜，佩戴太阳镜。'
    if (uv <= 7) return '涂抹 SPF30+ 防晒霜，穿戴防晒衣物，尽量避免中午时段暴晒。'
    if (uv <= 10) return '涂抹 SPF50+ 防晒霜，穿着防晒衣帽和太阳镜，中午时段避免外出。'
    return '尽量避免外出，必须外出时采用最高级别防护措施。'
  }

  private getSelectedDate(): string {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    return formatDate(new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000))
  }

  private buildDaySlots(): DaySlot[] {
    const today = new Date(); today.setHours(0, 0, 0, 0)
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    const slots: DaySlot[] = []
    for (let i = -1; i <= 5; i++) {
      const d = new Date(today.getTime() + i * 86400000)
      const ds = formatDate(d)
      const fc = all.find((f: ForecastDay) => f.fxDate === ds)
      slots.push({
        dateStr: ds, label: getDayLabel(ds),
        monthDay: (d.getMonth() + 1) + '/' + d.getDate(),
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
              Text(slot.tempMax + '°').fontSize(11).fontColor('rgba(255,255,255,0.70)')
              Text(slot.tempMin + '°').fontSize(11).fontColor('rgba(255,255,255,0.35)')
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

  private buildSyntheticUvPoints(): UvHourPoint[] {
    const maxUv = this.getCurrentUv()
    if (maxUv <= 0) return []
    const pts: UvHourPoint[] = []
    for (let hour = 5; hour <= 20; hour++) {
      const distFromNoon = Math.abs(hour - 13)
      const sigma = 3.0
      const bellValue = Math.exp(-(distFromNoon * distFromNoon) / (2 * sigma * sigma))
      const uv = Math.round(maxUv * bellValue * 10) / 10
      pts.push(new UvHourPoint(hour, uv))
    }
    return pts
  }

  private getUvAreaGradientColor(uv: number): string {
    if (uv <= 2) return '#00E676'
    if (uv <= 5) return '#A8D600'
    if (uv <= 7) return '#FF9500'
    if (uv <= 10) return '#FF5252'
    return '#D500F9'
  }

  private drawUvChart(): void {
    const pts = this.buildSyntheticUvPoints()
    if (pts.length < 2) return

    const w = this.chartWidth
    const h = this.chartHeight
    if (w <= 0 || h <= 0) return

    const maxUvVal = Math.max(...pts.map(p => p.uv))
    const yMax = maxUvVal <= 3 ? 5 : Math.ceil(maxUvVal / 3) * 3
    const yMin = 0

    const pl = 52; const pr = 20; const pt = 28; const pb = 56
    const cw = w - pl - pr
    const ch = h - pt - pb
    const toX = (i: number) => pl + (cw / (pts.length - 1)) * i
    const toY = (v: number) => pt + ch - ((v - yMin) / (yMax - yMin)) * ch

    const ctx = this.ctx
    ctx.clearRect(0, 0, w, h)

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'
    ctx.lineWidth = 1
    for (let i = 0; i <= 4; i++) {
      const y = pt + (ch / 4) * i
      ctx.beginPath(); ctx.moveTo(pl, y); ctx.lineTo(w - pr, y); ctx.stroke()
      ctx.fillStyle = 'rgba(255,255,255,0.55)'
      ctx.font = '28px sans-serif'
      ctx.textAlign = 'end'
      ctx.fillText('' + Math.round(yMin + ((yMax - yMin) / 4) * (4 - i)), pl - 6, y + 10)
    }

    ctx.fillStyle = 'rgba(255,255,255,0.50)'
    ctx.font = '26px sans-serif'
    ctx.textAlign = 'center'
    const xs = Math.max(1, Math.floor(pts.length / 6))
    for (let i = 0; i < pts.length; i += xs) {
      ctx.fillText('' + pts[i].hour, toX(i), h - pb + 22)
    }
    ctx.textAlign = 'start'

    ctx.beginPath()
    ctx.moveTo(toX(0), pt + ch)
    for (let i = 0; i < pts.length; i++) {
      ctx.lineTo(toX(i), toY(pts[i].uv))
    }
    ctx.lineTo(toX(pts.length - 1), pt + ch)
    ctx.closePath()
    const areaGrad = ctx.createLinearGradient(0, pt, 0, pt + ch)
    const mainColor = this.getUvAreaGradientColor(this.getCurrentUv())
    areaGrad.addColorStop(0, mainColor + '66')
    areaGrad.addColorStop(1, mainColor + '05')
    ctx.fillStyle = areaGrad
    ctx.fill()

    const lineGrad = ctx.createLinearGradient(0, pt, 0, pt + ch)
    lineGrad.addColorStop(0, mainColor)
    lineGrad.addColorStop(1, mainColor + '88')
    ctx.strokeStyle = lineGrad
    ctx.lineWidth = 4
    ctx.lineJoin = 'round'
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) {
      if (i === 0) {
        ctx.moveTo(toX(i), toY(pts[i].uv))
      } else {
        ctx.lineTo(toX(i), toY(pts[i].uv))
      }
    }
    ctx.stroke()

    const thresholdUv = 3
    const threshY = toY(thresholdUv)
    ctx.strokeStyle = 'rgba(255,255,255,0.35)'
    ctx.lineWidth = 2
    ctx.setLineDash([10, 6])
    ctx.beginPath()
    ctx.moveTo(pl, threshY)
    ctx.lineTo(w - pr, threshY)
    ctx.stroke()
    ctx.setLineDash([])

    ctx.fillStyle = 'rgba(255,255,255,0.50)'
    ctx.font = '22px sans-serif'
    ctx.textAlign = 'start'
    ctx.fillText('中等(3)', w - pr - 70, threshY - 6)

    const xStepLabel = Math.max(1, Math.floor(pts.length / 6))
    for (let i = 0; i < pts.length; i += xStepLabel) {
      const x = toX(i)
      const y = toY(pts[i].uv)
      ctx.fillStyle = mainColor
      ctx.beginPath()
      ctx.arc(x, y, 6, 0, Math.PI * 2)
      ctx.fill()
      ctx.fillStyle = 'rgba(255,255,255,0.85)'
      ctx.font = '28px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText('' + pts[i].uv, x, y - 14)
      ctx.textAlign = 'start'
    }
  }

  private getUvDayList(): UvDayItem[] {
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    if (all.length === 0) return []

    const today = new Date(); today.setHours(0, 0, 0, 0)
    const currentDate = formatDate(today)
    const out: UvDayItem[] = []

    for (let i = -1; i <= 5; i++) {
      const d = new Date(today.getTime() + i * 86400000)
      const ds = formatDate(d)
      const forecast = all.find(f => f.fxDate === ds)
      const uvNum = forecast ? (Number(forecast.uvIndex) || 0) : 0

      out.push({
        label: getDayLabel(ds),
        dateStr: ds,
        uvValue: forecast ? forecast.uvIndex : '--',
        uvColor: forecast ? this.getUvColor(uvNum) : 'rgba(255,255,255,0.25)',
        uvLevel: forecast ? this.getUvLevel(uvNum) : '--',
        isToday: ds === currentDate
      })
    }
    return out
  }

  getBarColorByIndex(idx: number): string {
    const colors = ['#00e676', '#ffd600', '#ff9100', '#ff5252', '#d500f9']
    return colors[idx] || 'rgba(255,255,255,0.1)'
  }

  private getUvComparison(): string {
    const all = this.payload.forecastDays.length > 0 ? this.payload.forecastDays : this.payload.forecast15Days
    if (all.length < 2) return '暂无比较数据。'
    const todayUv = Number(all[0].uvIndex)
    const yesterdayUv = Number(all.length > 1 ? all[1].uvIndex : '')
    if (isNaN(todayUv) || todayUv <= 0) return '暂无比较数据。'
    if (isNaN(yesterdayUv) || yesterdayUv <= 0) return '今天最高紫外线指数为 ' + todayUv + '（' + this.getUvLevel(todayUv) + '）。'
    if (todayUv > yesterdayUv) return '今天最高紫外线指数比昨天高（' + todayUv + ' vs ' + yesterdayUv + '）。'
    if (todayUv < yesterdayUv) return '今天最高紫外线指数比昨天低（' + todayUv + ' vs ' + yesterdayUv + '）。'
    return '今天最高紫外线指数与昨天类似（' + todayUv + '）。'
  }

  build() {
    Column() {
      Row() {
        Text(this.payload.cityName + ' · 紫外线')
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
      .padding({ left: 16, right: 8, top: 10, bottom: 2 })

      this.CalendarStrip()
      Divider().color('rgba(255,255,255,0.06)').width('90%')

      Scroll() {
        Column() {
          Column() {
            Text(this.getCurrentUv() > 0 ? '' + this.getCurrentUv() : '--')
              .fontSize(56)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getCurrentUv() > 0 ? this.getUvColor(this.getCurrentUv()) : 'rgba(255,255,255,0.25)')
              .margin({ bottom: 4 })

            Text(this.getCurrentUv() > 0 ? this.getUvLevel(this.getCurrentUv()) : '')
              .fontSize(16)
              .fontColor(this.getCurrentUv() > 0 ? this.getUvColor(this.getCurrentUv()) : 'rgba(255,255,255,0.25)')
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 4 })

            Text('基于世界卫生组织 UVI')
              .fontSize(11)
              .fontColor('rgba(255,255,255,0.25)')
              .margin({ bottom: 20 })

            Row({ space: 0 }) {
              ForEach(['最弱', '中等', '较强', '很强', '极强'], (label: string, idx: number) => {
                Text(label)
                  .fontSize(9)
                  .fontColor(this.getCurrentUv() > 0 && this.getUvLevel(this.getCurrentUv()) === label ? '#ffffff' : 'rgba(255,255,255,0.30)')
                  .fontWeight(this.getCurrentUv() > 0 && this.getUvLevel(this.getCurrentUv()) === label ? FontWeight.Bold : FontWeight.Normal)
                  .textAlign(TextAlign.Center)
                  .width('20%')
                  .padding({ top: 3, bottom: 3 })
                  .backgroundColor(this.getBarColorByIndex(idx))
                  .borderRadius(this.getCurrentUv() > 0 && this.getUvLevel(this.getCurrentUv()) === label ? 6 : 4)
              })
            }
            .width('100%')
            .margin({ bottom: 20 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          if (this.getCurrentUv() > 0) {
            Canvas(this.ctx)
              .width('100%').height(340)
              .onAreaChange((_old: Area, nv: Area) => {
                const nw = Number(nv.width)
                const nh = Number(nv.height)
                if (nw > 0) this.chartWidth = nw
                if (nh > 0) this.chartHeight = nh
              })
              .onReady(() => { this.drawUvChart() })
          }

          Column() {
            Text('🛡️ 防护建议')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.50)')
              .margin({ bottom: 8 })

            Text(this.getCurrentUv() > 0 ? this.getAdvice(this.getCurrentUv()) : '暂无数据')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.70)')
              .lineHeight(20)
          }
          .width('100%')
          .padding(14)
          .backgroundColor('rgba(255,255,255,0.04)')
          .borderRadius(12)
          .margin({ bottom: 16 })

          Column({ space: 4 }) {
            Text('每日比较').fontSize(13).fontColor('rgba(255,255,255,0.30)').margin({ bottom: 4 })
            Text(this.getUvComparison())
              .fontSize(12).fontColor('rgba(255,255,255,0.50)').lineHeight(18)
          }.width('100%').padding(16).backgroundColor('rgba(255,255,255,0.04)')
            .borderRadius(12).margin({ bottom: 16 })

          Text('7 天紫外线')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.50)')
            .margin({ bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Column({ space: 4 }) {
            ForEach(this.getUvDayList(), (item: UvDayItem, idx: number) => {
              Row() {
                Text(item.isToday ? item.label + ' · 今天' : item.label)
                  .fontSize(13)
                  .fontColor(item.isToday ? '#ffffff' : 'rgba(255,255,255,0.55)')
                  .fontWeight(item.isToday ? FontWeight.Bold : FontWeight.Normal)
                  .width(80)
                Blank()
                Text(item.uvValue)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(item.uvColor)
                  .width(40)
                  .textAlign(TextAlign.Center)
                Text(item.uvLevel)
                  .fontSize(11)
                  .fontColor(item.uvColor)
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(item.isToday ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.03)')
              .borderRadius(10)
              .onClick(() => {
                this.selectedDayIndex = idx
              })
            })
          }
          .width('100%')

          Blank().height(40)
        }.width('100%')
      }.scrollable(ScrollDirection.Vertical).scrollBar(BarState.Off).layoutWeight(1).edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('94%')
    .backgroundColor('#1C1C1E')
    .borderRadius({ topLeft: 20, topRight: 20 }).padding({ bottom: 16 })
  }
}
