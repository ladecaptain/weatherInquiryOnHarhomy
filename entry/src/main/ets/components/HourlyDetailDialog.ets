import { HourlyForecastItem, ForecastDay, CurrentWeatherData } from '../model/WeatherModel'
import { formatTempWithUnit } from '../services/TemperatureService'
import { formatDate, getDayLabel, getWeatherIconResource } from '../utils/WeatherUtils'

/* ────── 数据类 ────── */

@Observed
export class HourlyDetailPayload {
  hourlyData: HourlyForecastItem[] = []
  selectedHourIndex: number = -1
  forecastDays: ForecastDay[] = []
  forecast15Days: ForecastDay[] = []
  currentWeather: CurrentWeatherData | null = null
  cityName: string = ''
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

interface ChartPoint {
  hour: number
  temp: number
  icon: string
  text: string
}

class TempRange {
  min: string = '--'
  max: string = '--'
  constructor(min: string, max: string) {
    this.min = min
    this.max = max
  }
}

/* ────── 弹窗组件 ────── */

@CustomDialog
export struct HourlyDetailDialog {
  controller: CustomDialogController
  @Link dialogPayload: HourlyDetailPayload
  @State @Watch('onDayChanged') selectedDayIndex: number = 1
  @StorageProp('tempUnit') tempUnit: string = '°C'

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  onDayChanged(): void {
    setTimeout(() => { this.drawChart() }, 50)
  }

  /* ── 日期工具 ── */

  private getSelectedDate(): string {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const d = new Date(today.getTime() + (this.selectedDayIndex - 1) * 86400000)
    return formatDate(d)
  }

  private getSelectedDayForecast(): ForecastDay | null {
    const selDate = this.getSelectedDate()
    const all = this.dialogPayload.forecastDays.length > 0
      ? this.dialogPayload.forecastDays
      : this.dialogPayload.forecast15Days
    for (const f of all) {
      if (f.fxDate === selDate) {
        return f
      }
    }
    return null
  }

  private getFilteredHourly(): HourlyForecastItem[] {
    const selDate = this.getSelectedDate()
    const out: HourlyForecastItem[] = []
    for (const item of this.dialogPayload.hourlyData) {
      if (formatDate(new Date(item.fxTime)) === selDate) {
        out.push(item)
      }
    }
    return out
  }

  private getFilteredHourlyText(): string {
    const n = this.getFilteredHourly().length
    if (n === 0) {
      return '暂无逐小时数据'
    }
    return `${n}个时次`
  }

  /* ── 日历 ── */

  private buildDaySlots(): DaySlot[] {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const allForecasts = this.dialogPayload.forecastDays.length > 0
      ? this.dialogPayload.forecastDays
      : this.dialogPayload.forecast15Days
    const slots: DaySlot[] = []

    for (let i = -1; i <= 5; i++) {
      const d = new Date(today.getTime() + i * 86400000)
      const dateStr = formatDate(d)
      const fc = allForecasts.find((f: ForecastDay) => f.fxDate === dateStr)

      slots.push({
        dateStr,
        label: getDayLabel(dateStr),
        monthDay: `${d.getMonth() + 1}/${d.getDate()}`,
        iconDay: fc ? fc.iconDay : '',
        tempMax: fc ? fc.tempMax : '--',
        tempMin: fc ? fc.tempMin : '--',
        isToday: i === 0
      })
    }
    return slots
  }

  @Builder
  CalendarStrip() {
    Row() {
      Scroll() {
        Row({ space: 12 }) {
          ForEach(this.buildDaySlots(), (slot: DaySlot, idx: number) => {
            Column() {
              Text(slot.label)
                .fontSize(11)
                .fontColor(slot.isToday ? '#6db3f2' : 'rgba(255,255,255,0.50)')
                .fontWeight(slot.isToday ? FontWeight.Bold : FontWeight.Normal)
                .margin({ bottom: 2 })

              Text(slot.monthDay)
                .fontSize(10)
                .fontColor('rgba(255,255,255,0.35)')
                .margin({ bottom: 6 })

              if (slot.iconDay !== '') {
                Image(getWeatherIconResource(slot.iconDay))
                  .width(30)
                  .height(30)
                  .margin({ bottom: 4 })
              }
              if (slot.iconDay === '') {
                Text('--')
                  .fontSize(10)
                  .fontColor('rgba(255,255,255,0.15)')
                  .margin({ bottom: 4 })
              }

              Text(formatTempWithUnit(slot.tempMax, this.tempUnit))
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.70)')
              Text(formatTempWithUnit(slot.tempMin, this.tempUnit))
                .fontSize(11)
                .fontColor('rgba(255,255,255,0.35)')
            }
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .backgroundColor(this.selectedDayIndex === idx
              ? 'rgba(109,179,242,0.18)'
              : 'rgba(255,255,255,0.04)')
            .borderRadius(14)
            .border({
              width: this.selectedDayIndex === idx ? 1.5 : 0,
              color: 'rgba(109,179,242,0.55)'
            })
            .onClick(() => {
              this.selectedDayIndex = idx
            })
          })
        }
        .padding({ left: 6, right: 6 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  /* ── 折线图 ── */

  private toChartPoints(items: HourlyForecastItem[]): ChartPoint[] {
    const out: ChartPoint[] = []
    for (const item of items) {
      const t = parseFloat(item.temp)
      if (!isNaN(t)) {
        out.push({
          hour: new Date(item.fxTime).getHours(),
          temp: t,
          icon: item.icon,
          text: item.text
        })
      }
    }
    return out
  }

  private convertTemp(celsius: number): number {
    return this.tempUnit === '°F' ? celsius * 9 / 5 + 32 : celsius
  }

  @State chartWidth: number = 300
  @State chartHeight: number = 560

  private drawChart(): void {
    const filtered = this.getFilteredHourly()
    const raw = this.toChartPoints(filtered)
    if (raw.length === 0) {
      return
    }

    const sorted: ChartPoint[] = []
    for (const p of raw) {
      sorted.push({ hour: p.hour, temp: this.convertTemp(p.temp), icon: p.icon, text: p.text })
    }
    sorted.sort((a, b) => a.hour - b.hour)

    const w = this.chartWidth
    const h = this.chartHeight
    if (w <= 0 || h <= 0) {
      return
    }

    const temps: number[] = []
    for (const p of sorted) {
      temps.push(p.temp)
    }
    let minT = Math.min(...temps)
    let maxT = Math.max(...temps)
    const range = maxT - minT
    if (range < 2) { minT -= 1; maxT += 1 }
    else { minT -= range * 0.12; maxT += range * 0.12 }

    const padL = 72
    const padR = 28
    const padTop = 36
    const padBot = 64
    const cw = w - padL - padR
    const ch = h - padTop - padBot

    const toX = (i: number): number => padL + (cw / (sorted.length - 1 || 1)) * i
    const toY = (temp: number): number => padTop + ch - ((temp - minT) / (maxT - minT)) * ch

    const ctx = this.ctx
    ctx.clearRect(0, 0, w, h)

    // Y 轴网格 + 标签
    const ySteps = 5
    for (let i = 0; i <= ySteps; i++) {
      const y = padTop + (ch / ySteps) * i
      const val = maxT - ((maxT - minT) / ySteps) * i
      ctx.beginPath()
      ctx.moveTo(padL, y)
      ctx.lineTo(w - padR, y)
      ctx.strokeStyle = 'rgba(255,255,255,0.08)'
      ctx.lineWidth = 1
      ctx.stroke()
      ctx.fillStyle = 'rgba(255,255,255,0.60)'
      ctx.font = '30px sans-serif'
      ctx.textAlign = 'right'
      ctx.fillText(`${Math.round(val)}°`, padL - 10, y + 12)
    }

    // X 轴标签
    const labelStep = sorted.length <= 8 ? 2 : (sorted.length <= 16 ? 3 : 4)
    ctx.fillStyle = 'rgba(255,255,255,0.55)'
    ctx.font = '28px sans-serif'
    ctx.textAlign = 'center'
    for (let i = 0; i < sorted.length; i++) {
      if (i % labelStep === 0 || i === sorted.length - 1) {
        ctx.fillText(`${sorted[i].hour}时`, toX(i), h - padBot + 28)
      }
    }

    // 渐变填充
    const gradient = ctx.createLinearGradient(0, padTop, 0, padTop + ch)
    gradient.addColorStop(0, 'rgba(109,179,242,0.40)')
    gradient.addColorStop(1, 'rgba(109,179,242,0.03)')

    ctx.beginPath()
    ctx.moveTo(toX(0), padTop + ch)
    for (let i = 0; i < sorted.length; i++) {
      ctx.lineTo(toX(i), toY(sorted[i].temp))
    }
    ctx.lineTo(toX(sorted.length - 1), padTop + ch)
    ctx.closePath()
    ctx.fillStyle = gradient
    ctx.fill()

    // 折线
    ctx.beginPath()
    ctx.moveTo(toX(0), toY(sorted[0].temp))
    for (let i = 1; i < sorted.length; i++) {
      ctx.lineTo(toX(i), toY(sorted[i].temp))
    }
    ctx.strokeStyle = '#6db3f2'
    ctx.lineWidth = 5
    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'
    ctx.stroke()

    // 数据点
    const selIdx = this.dialogPayload.selectedHourIndex
    const selItem = selIdx >= 0 && selIdx < this.dialogPayload.hourlyData.length
      ? this.dialogPayload.hourlyData[selIdx]
      : null
    const selHour = selItem ? new Date(selItem.fxTime).getHours() : -1

    const labelInterval = Math.max(1, Math.floor(sorted.length / 10))
    for (let i = 0; i < sorted.length; i++) {
      const cx = toX(i)
      const cy = toY(sorted[i].temp)
      const isSelected = sorted[i].hour === selHour

      if (isSelected) {
        ctx.beginPath()
        ctx.arc(cx, cy, 14, 0, 2 * Math.PI)
        ctx.fillStyle = 'rgba(109,179,242,0.30)'
        ctx.fill()
        ctx.beginPath()
        ctx.arc(cx, cy, 8, 0, 2 * Math.PI)
        ctx.fillStyle = '#6db3f2'
        ctx.fill()
        ctx.strokeStyle = '#ffffff'
        ctx.lineWidth = 3
        ctx.stroke()
        ctx.fillStyle = '#ffffff'
        ctx.font = 'bold 32px sans-serif'
        ctx.textAlign = 'center'
        ctx.fillText(`${Math.round(sorted[i].temp)}°`, cx, cy - 20)
      } else {
        ctx.beginPath()
        ctx.arc(cx, cy, 6, 0, 2 * Math.PI)
        ctx.fillStyle = 'rgba(255,255,255,0.60)'
        ctx.fill()
        if (i % labelInterval === 0 || i === 0 || i === sorted.length - 1) {
          ctx.fillStyle = 'rgba(255,255,255,0.75)'
          ctx.font = '28px sans-serif'
          ctx.textAlign = 'center'
          ctx.fillText(`${Math.round(sorted[i].temp)}°`, cx, cy - 14)
        }
      }
    }
  }

  /* ── 简报辅助方法 ── */

  private getSelectedHourItem(): HourlyForecastItem | null {
    const si = this.dialogPayload.selectedHourIndex
    if (si >= 0 && si < this.dialogPayload.hourlyData.length) {
      return this.dialogPayload.hourlyData[si]
    }
    return null
  }

  private getWeatherChangeText(): string {
    const items = this.getFilteredHourly()
    if (items.length < 2) {
      return '全天天气稳定'
    }
    for (let i = 1; i < items.length; i++) {
      if (items[i].text !== items[i - 1].text) {
        const time = new Date(items[i].fxTime)
        const hour = time.getHours()
        const prefix = time.getDate() === new Date().getDate() ? '今天' : '明天'
        return `预计${prefix}${hour}时转为${items[i].text}`
      }
    }
    return '全天天气稳定'
  }

  private getFeelsRange(): TempRange {
    const items = this.getFilteredHourly()
    if (items.length === 0) {
      return new TempRange('--', '--')
    }
    const temps: number[] = []
    for (const i of items) {
      const t = parseFloat(i.temp)
      if (!isNaN(t)) {
        temps.push(t)
      }
    }
    if (temps.length === 0) {
      return new TempRange('--', '--')
    }
    return new TempRange(
      formatTempWithUnit(Math.min(...temps).toString(), this.tempUnit),
      formatTempWithUnit(Math.max(...temps).toString(), this.tempUnit)
    )
  }

  private getFeelsRangeStr(): string {
    const r = this.getFeelsRange()
    if (r.min === '--') {
      return '--'
    }
    return `${r.min} ~ ${r.max}`
  }

  private getDayTempRange(): string {
    const fc = this.getSelectedDayForecast()
    if (fc && fc.tempMax !== '' && fc.tempMin !== '') {
      return `${formatTempWithUnit(fc.tempMin, this.tempUnit)} ~ ${formatTempWithUnit(fc.tempMax, this.tempUnit)}`
    }
    return '--'
  }

  private getSelectedHourTemp(): string {
    const item = this.getSelectedHourItem()
    if (item) {
      return formatTempWithUnit(item.temp, this.tempUnit)
    }
    return '--'
  }

  private getSelectedHourText(): string {
    const item = this.getSelectedHourItem()
    if (item) {
      return item.text
    }
    return ''
  }

  private getSelectedWind(): string {
    const item = this.getSelectedHourItem()
    if (item) {
      return `${item.windDir} ${item.windScale}级`
    }
    return '--'
  }

  private getSelectedHumidity(): string {
    const item = this.getSelectedHourItem()
    if (item) {
      return `${item.humidity}%`
    }
    return '--'
  }

  private getSelectedPop(): string {
    const item = this.getSelectedHourItem()
    if (item) {
      return `${item.pop}%`
    }
    return '--'
  }

  private getSelectedPrecip(): string {
    const item = this.getSelectedHourItem()
    if (item) {
      return `${item.precip}mm`
    }
    return '--'
  }

  private getSelectedPressure(): string {
    const item = this.getSelectedHourItem()
    if (item) {
      return `${item.pressure}hPa`
    }
    return '--'
  }

  private getSelectedCloud(): string {
    const item = this.getSelectedHourItem()
    if (item) {
      return `${item.cloud}%`
    }
    return '--'
  }

  // 每日预报字段辅助方法
  private getDailyIconDay(): string {
    const fc = this.getSelectedDayForecast()
    return fc ? fc.iconDay : ''
  }

  private getDailyTextDay(): string {
    const fc = this.getSelectedDayForecast()
    return fc ? fc.textDay : '--'
  }

  private getDailyTempRange(): string {
    const fc = this.getSelectedDayForecast()
    if (fc && fc.tempMax !== '' && fc.tempMin !== '') {
      return `${formatTempWithUnit(fc.tempMax, this.tempUnit)} / ${formatTempWithUnit(fc.tempMin, this.tempUnit)}`
    }
    return '--'
  }

  private getDailyWind(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return `${fc.windDirDay} ${fc.windScaleDay}级`
    }
    return '--'
  }

  private getDailyHumidity(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return `${fc.humidity}%`
    }
    return '--'
  }

  private getDailySunrise(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return fc.sunrise
    }
    return '--'
  }

  private getDailySunset(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return fc.sunset
    }
    return '--'
  }

  private getDailyPrecip(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return `${fc.precip}mm`
    }
    return '--'
  }

  private getDailyPressure(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return `${fc.pressure}hPa`
    }
    return '--'
  }

  private getDailyUV(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return fc.uvIndex
    }
    return '--'
  }

  private getDailyVis(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return `${fc.vis}km`
    }
    return '--'
  }

  private getDailyCloud(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return `${fc.cloud}%`
    }
    return '--'
  }

  private getDailyMoonPhase(): string {
    const fc = this.getSelectedDayForecast()
    if (fc) {
      return fc.moonPhase
    }
    return '--'
  }

  /* ── 构建 ── */

  build() {
    Column() {
      // ── 标题栏 ──
      Row() {
        Text(this.dialogPayload.cityName !== '' ? this.dialogPayload.cityName : '天气详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
        Blank()
        Button() {
          Image($r('sys.media.ohos_ic_public_close'))
            .width(22)
            .height(22)
            .fillColor('#ffffff')
        }
        .width(38)
        .height(38)
        .backgroundColor('rgba(255,255,255,0.10)')
        .borderRadius(19)
        .onClick(() => this.controller.close())
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 10, bottom: 2 })

      // ── 日历条 ──
      this.CalendarStrip()

      Divider()
        .color('rgba(255,255,255,0.06)')
        .width('90%')

      // ── 可滚动内容 ──
      Scroll() {
        Column() {
          // ============ 图表区域 ============
          Column() {
            Row() {
              Text('温度变化')
                .fontSize(17)
                .fontColor('rgba(255,255,255,0.70)')
              Blank()
              Text(this.getSelectedDate())
                .fontSize(12)
                .fontColor('rgba(255,255,255,0.30)')
            }
            .width('100%')
            .margin({ bottom: 8 })

            // 无逐小时数据 + 有每日预报
            if (this.getFilteredHourly().length === 0 && this.getSelectedDayForecast() !== null) {
              Column() {
                Row({ space: 14 }) {
                  if (this.getDailyIconDay() !== '') {
                    Image(getWeatherIconResource(this.getDailyIconDay()))
                      .width(52)
                      .height(52)
                  }
                  if (this.getDailyIconDay() === '') {
                    Text('--')
                      .fontSize(14)
                      .fontColor('rgba(255,255,255,0.15)')
                      .width(52)
                      .height(52)
                      .textAlign(TextAlign.Center)
                  }

                  Column({ space: 4 }) {
                    Text(this.getDailyTextDay())
                      .fontSize(17)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#ffffff')
                    Text(this.getDailyTempRange())
                      .fontSize(14)
                      .fontColor('rgba(255,255,255,0.55)')
                  }
                  .alignItems(HorizontalAlign.Start)
                }
                .width('100%')
                .justifyContent(FlexAlign.Start)
                .padding({ left: 8, top: 10, bottom: 10 })
                .backgroundColor('rgba(255,255,255,0.04)')
                .borderRadius(12)

                Row({ space: 20 }) {
                  Column({ space: 4 }) {
                    Text('💨 风力')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyWind())
                      .fontSize(13)
                      .fontColor('rgba(255,255,255,0.65)')
                  }
                  Column({ space: 4 }) {
                    Text('💧 湿度')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyHumidity())
                      .fontSize(13)
                      .fontColor('rgba(255,255,255,0.65)')
                  }
                  Column({ space: 4 }) {
                    Text('🌅 日出/落')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(`${this.getDailySunrise()} / ${this.getDailySunset()}`)
                      .fontSize(13)
                      .fontColor('rgba(255,255,255,0.65)')
                  }
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceEvenly)
                .margin({ top: 14 })
                .padding({ top: 14, bottom: 14 })
                .backgroundColor('rgba(255,255,255,0.04)')
                .borderRadius(12)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }

            // 无任何数据
            if (this.getFilteredHourly().length === 0 && this.getSelectedDayForecast() === null) {
              Text('暂无该日天气数据')
                .fontSize(14)
                .fontColor('rgba(255,255,255,0.30)')
                .padding({ top: 40, bottom: 40 })
            }

            // 有逐小时数据 → 画折线图
            if (this.getFilteredHourly().length > 0) {
              Canvas(this.ctx)
                .width('100%')
                .height(520)
                .onAreaChange((oldValue: Area, newValue: Area) => {
                  const nw = newValue.width as number
                  const nh = newValue.height as number
                  if (nw > 0) this.chartWidth = nw
                  if (nh > 0) this.chartHeight = nh
                })
                .onReady(() => {
                  this.drawChart()
                })
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 8, bottom: 10 })
          .backgroundColor('rgba(255,255,255,0.03)')
          .borderRadius(14)
          .margin({ top: 10, left: 10, right: 10 })

          // ============ 天气简报 ============
          Column() {
            Text('天气简报')
              .fontSize(15)
              .fontColor('rgba(255,255,255,0.60)')
              .margin({ bottom: 16 })

            // 情况 A：无逐小时数据 + 有每日预报
            if (this.getFilteredHourly().length === 0 && this.getSelectedDayForecast() !== null) {
              Column({ space: 16 }) {
                Row({ space: 12 }) {
                  Text('全天概况')
                    .fontSize(13)
                    .fontColor('rgba(255,255,255,0.40)')
                  Text(this.getDailyTextDay())
                    .fontSize(15)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }

                Row({ space: 22 }) {
                  Column({ space: 4 }) {
                    Text('降水量')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyPrecip())
                      .fontSize(14)
                      .fontColor('#ffffff')
                      .fontWeight(FontWeight.Medium)
                  }
                  Column({ space: 4 }) {
                    Text('气压')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyPressure())
                      .fontSize(14)
                      .fontColor('#ffffff')
                      .fontWeight(FontWeight.Medium)
                  }
                  Column({ space: 4 }) {
                    Text('紫外线')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyUV())
                      .fontSize(14)
                      .fontColor('#ffffff')
                      .fontWeight(FontWeight.Medium)
                  }
                }

                Row({ space: 22 }) {
                  Column({ space: 4 }) {
                    Text('能见度')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyVis())
                      .fontSize(14)
                      .fontColor('#ffffff')
                      .fontWeight(FontWeight.Medium)
                  }
                  Column({ space: 4 }) {
                    Text('云量')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyCloud())
                      .fontSize(14)
                      .fontColor('#ffffff')
                      .fontWeight(FontWeight.Medium)
                  }
                  Column({ space: 4 }) {
                    Text('月相')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyMoonPhase())
                      .fontSize(14)
                      .fontColor('#ffffff')
                      .fontWeight(FontWeight.Medium)
                  }
                }
              }
              .width('100%')
            }

            // 情况 B：无逐小时数据 + 无每日预报
            if (this.getFilteredHourly().length === 0 && this.getSelectedDayForecast() === null) {
              Text('暂无更多信息')
                .fontSize(14)
                .fontColor('rgba(255,255,255,0.30)')
                .padding({ top: 12, bottom: 12 })
            }

            // 情况 C：有逐小时数据 + 有选中小时
            if (this.getFilteredHourly().length > 0 && this.getSelectedHourItem() !== null) {
              Row() {
                Text(this.getSelectedHourTemp())
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#ffffff')
                Text(`，${this.getSelectedHourText()}`)
                  .fontSize(16)
                  .fontColor('rgba(255,255,255,0.70)')
              }
              .margin({ bottom: 10 })

              Text(this.getWeatherChangeText())
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.50)')
                .margin({ bottom: 18 })

              Row({ space: 28 }) {
                Column({ space: 4 }) {
                  Text('气温范围')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.30)')
                  Text(this.getFeelsRangeStr())
                    .fontSize(16)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }
                Column({ space: 4 }) {
                  Text('体感温度')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.30)')
                  Text(this.getFeelsRangeStr())
                    .fontSize(16)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }
              }
              .margin({ bottom: 20 })

              Row({ space: 22 }) {
                Column({ space: 4 }) {
                  Text('💨 风力风向')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.30)')
                  Text(this.getSelectedWind())
                    .fontSize(14)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }
                Column({ space: 4 }) {
                  Text('💧 相对湿度')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.30)')
                  Text(this.getSelectedHumidity())
                    .fontSize(14)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }
                Column({ space: 4 }) {
                  Text('🌧 降水概率')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.30)')
                  Text(this.getSelectedPop())
                    .fontSize(14)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }
              }
              .margin({ bottom: 18 })

              Row({ space: 22 }) {
                Column({ space: 4 }) {
                  Text('降水量')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.30)')
                  Text(this.getSelectedPrecip())
                    .fontSize(14)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }
                Column({ space: 4 }) {
                  Text('大气压')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.30)')
                  Text(this.getSelectedPressure())
                    .fontSize(14)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }
                Column({ space: 4 }) {
                  Text('云量')
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.30)')
                  Text(this.getSelectedCloud())
                    .fontSize(14)
                    .fontColor('#ffffff')
                    .fontWeight(FontWeight.Medium)
                }
              }

              // 当日概览（额外参考）
              if (this.getSelectedDayForecast() !== null) {
                Divider()
                  .color('rgba(255,255,255,0.06)')
                  .width('85%')
                  .margin({ top: 20, bottom: 20 })

                Text('当日概览')
                  .fontSize(13)
                  .fontColor('rgba(255,255,255,0.40)')
                  .margin({ bottom: 12 })

                Row({ space: 22 }) {
                  Column({ space: 4 }) {
                    Text('日出')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailySunrise())
                      .fontSize(13)
                      .fontColor('#ffffff')
                  }
                  Column({ space: 4 }) {
                    Text('日落')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailySunset())
                      .fontSize(13)
                      .fontColor('#ffffff')
                  }
                  Column({ space: 4 }) {
                    Text('紫外线')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyUV())
                      .fontSize(13)
                      .fontColor('#ffffff')
                  }
                  Column({ space: 4 }) {
                    Text('月相')
                      .fontSize(11)
                      .fontColor('rgba(255,255,255,0.30)')
                    Text(this.getDailyMoonPhase())
                      .fontSize(13)
                      .fontColor('#ffffff')
                  }
                }
              }
            }

            // 情况 D：有逐小时数据但没有选中小时
            if (this.getFilteredHourly().length > 0 && this.getSelectedHourItem() === null) {
              Text('请在上方图表点击一个时次查看详情')
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.30)')
                .padding({ top: 20, bottom: 20 })
            }
          }
          .width('100%')
          .padding(18)
          .backgroundColor('rgba(255,255,255,0.05)')
          .borderRadius(14)
          .margin({ top: 12, left: 10, right: 10 })

          Blank()
            .height(40)
        }
        .width('100%')
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('92%')
    .backgroundColor('#1a1d28')
    .borderRadius({ topLeft: 20, topRight: 20 })
    .padding({ bottom: 16 })
  }
}
