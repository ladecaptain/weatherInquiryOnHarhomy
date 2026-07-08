/**
 * 详情弹窗通用 Payload — 所有6个详情弹窗复用此数据类
 */
import { HourlyForecastItem, ForecastDay, CurrentWeatherData, AirQualityData } from '../model/WeatherModel'

@Observed
export class DetailPayload {
  hourlyData: HourlyForecastItem[] = []
  forecastDays: ForecastDay[] = []
  forecast15Days: ForecastDay[] = []
  currentWeather: CurrentWeatherData | null = null
  cityName: string = ''
  aqiData: AirQualityData | null = null
  /** 弹窗类型标识 */
  dialogType: string = 'temp'
}
