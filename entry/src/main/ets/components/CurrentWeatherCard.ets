import { CurrentWeatherData } from '../model/WeatherModel'
import { formatTime, getWeatherIconResource } from '../utils/WeatherUtils'
import { tempService, formatTempWithUnit } from '../services/TemperatureService'

/**
 * 实时天气卡片组件（透明底）
 * 所有文字使用白色系，透过组件直接看到背景图
 */
@Component
export struct CurrentWeatherCard {
  @Prop weatherData: CurrentWeatherData | null = null
  @Prop cityName: string = ''
  @Prop tempMax: string = ''
  @Prop tempMin: string = ''
  @StorageProp('tempUnit') tempUnit: string = '°C'
  onTempClick?: () => void

  build() {
    Column() {
      if (this.weatherData === null) {
        Text('加载中...')
          .fontSize(18)
          .fontColor('rgba(255,255,255,0.4)')
          .textAlign(TextAlign.Center)
          .padding({ top: 60, bottom: 60 })
      } else {
        // 城市名
        Text(this.cityName)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
          .textShadow({ radius: 6, color: 'rgba(0,0,0,0.3)', offsetX: 0, offsetY: 1 })
          .margin({ bottom: 2 })

        // 更新时间
        Text(`更新 ${formatTime(this.weatherData.obsTime)}`)
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.55)')
          .margin({ bottom: 16 })

        // 天气图标
        Image(getWeatherIconResource(this.weatherData.icon))
          .width(90)
          .height(90)
          .margin({ bottom: 8 })

        // 温度大数字（点击打开趋势弹窗）
        Column() {
          Text(this.tempDisplay(this.weatherData.temp))
            .fontSize(56)
            .fontWeight(FontWeight.Lighter)
            .fontColor('#ffffff')
            .textShadow({ radius: 10, color: 'rgba(0,0,0,0.25)', offsetX: 0, offsetY: 2 })
            .margin({ bottom: 2 })
        }
        .onClick(() => { if (this.onTempClick) this.onTempClick() })

        // 天气描述
        Text(this.weatherData.text)
          .fontSize(18)
          .fontColor('rgba(255,255,255,0.80)')
          .margin({ bottom: 4 })

        // 体感温度
        Text(`体感 ${tempService().formatTemp(this.weatherData.feelsLike, this.tempUnit)}${this.tempUnit}`)
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.65)')
          .margin({ bottom: 24 })

        // 最高 / 最低温度
        Row({ space: 20 }) {
          Text(`最低：${tempService().formatTemp(this.tempMin, this.tempUnit)}${this.tempUnit}`)
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.70)')
          Text(`最高：${tempService().formatTemp(this.tempMax, this.tempUnit)}${this.tempUnit}`)
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.70)')
        }
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 28 })
  }

  /** 格式化温度显示（传入 this.tempUnit 建立 ArkTS 依赖） */
  private tempDisplay(celsius: string): string {
    return `${tempService().formatTemp(celsius, this.tempUnit)}${this.tempUnit}`
  }
}
