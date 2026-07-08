import { HourlyForecastItem } from '../model/WeatherModel'
import { formatHourlyTime, getWeatherIconResource, isRainIcon } from '../utils/WeatherUtils'
import { formatTempWithUnit } from '../services/TemperatureService'

/**
 * 逐小时天气预报组件
 * 透明底 + 毛玻璃效果，白色文字，适应深色背景
 */
@Component
export struct HourlyForecast {
  @Prop hourlyData: HourlyForecastItem[] = []
  @Prop isClearBg: boolean = false
  @StorageProp('tempUnit') tempUnit: string = '°C'
  onItemClick?: (index: number) => void

  build() {
    Column() {
      // 标题行
      Row() {
        Text('逐小时预报')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.90)')
        Blank()
        Text('温度 / 降水 / 风力')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.55)')
      }
      .width('100%')
      .padding({ left: 4, right: 4, bottom: 10 })

      if (this.hourlyData.length === 0) {
        Text('暂无逐小时预报数据')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.55)')
          .padding({ top: 10, bottom: 10 })
      } else {
        List() {
          ForEach(this.hourlyData, (item: HourlyForecastItem, index: number) => {
            ListItem() {
              Column() {
                Text(formatHourlyTime(item.fxTime))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('rgba(255,255,255,0.70)')
                  .margin({ bottom: 4 })

                Text(`${item.pop}%`)
                  .fontSize(13)
                  .fontColor(Number(item.pop) > 30 ? '#0A84FF' : 'rgba(255,255,255,0.55)')
                  .visibility(isRainIcon(item.icon) ? Visibility.Visible : Visibility.Hidden)
                  .margin({ bottom: 2 })

                Image(getWeatherIconResource(item.icon))
                  .width(28)
                  .height(28)
                  .margin({ bottom: 2 })

                Text(formatTempWithUnit(item.temp, this.tempUnit))
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#ffffff')
                  .margin({ bottom: 4 })

                Text(item.windDir)
                  .fontSize(13)
                  .fontColor('rgba(255,255,255,0.55)')
                  .maxLines(1)
                Text(`${item.windScale}级`)
                  .fontSize(13)
                  .fontColor('rgba(255,255,255,0.50)')
              }
              .alignItems(HorizontalAlign.Center)
              .padding({ top: 10, bottom: 10, left: 10, right: 10 })
              .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.30)' : 'rgba(0,0,0,0.20)')
              .borderRadius(10)
              .margin({ right: 8 })
            }
            .width(68)
            .onClick(() => {
              if (this.onItemClick) {
                this.onItemClick(index)
              }
            })
          }, (_item: HourlyForecastItem, index: number) => index.toString())
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .height(140)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.35)' : 'rgba(0,0,0,0.30)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
  }
}
