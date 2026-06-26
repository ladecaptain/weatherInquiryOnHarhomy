import { HourlyForecastItem } from '../model/WeatherModel'
import { formatHourlyTime, getWeatherIconResource, isRainIcon } from '../utils/WeatherUtils'

/**
 * 逐小时天气预报组件
 * 透明底 + 毛玻璃效果，白色文字，适应深色背景
 */
@Component
export struct HourlyForecast {
  @Prop hourlyData: HourlyForecastItem[] = []

  build() {
    Column() {
      // 标题行
      Row() {
        Text('逐小时预报')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.80)')
        Blank()
        Text('温度 / 降水 / 风力')
          .fontSize(11)
          .fontColor('rgba(255,255,255,0.30)')
      }
      .width('100%')
      .padding({ left: 4, right: 4, bottom: 10 })

      if (this.hourlyData.length === 0) {
        Text('暂无逐小时预报数据')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.35)')
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
                  .fontSize(11)
                  .fontColor(Number(item.pop) > 30 ? '#6db3f2' : 'rgba(255,255,255,0.25)')
                  .visibility(isRainIcon(item.icon) ? Visibility.Visible : Visibility.Hidden)
                  .margin({ bottom: 2 })

                Image(getWeatherIconResource(item.icon))
                  .width(28)
                  .height(28)
                  .margin({ bottom: 2 })

                Text(`${item.temp}°`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#ffffff')
                  .margin({ bottom: 4 })

                Text(item.windDir)
                  .fontSize(10)
                  .fontColor('rgba(255,255,255,0.35)')
                  .maxLines(1)
                Text(`${item.windScale}级`)
                  .fontSize(10)
                  .fontColor('rgba(255,255,255,0.25)')
              }
              .alignItems(HorizontalAlign.Center)
              .padding({ top: 10, bottom: 10, left: 10, right: 10 })
              .backgroundColor('rgba(255,255,255,0.06)')
              .borderRadius(10)
              .margin({ right: 8 })
            }
            .width(68)
          }, (_item: HourlyForecastItem, index: number) => index.toString())
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .height(140)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(255,255,255,0.06)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
  }
}
