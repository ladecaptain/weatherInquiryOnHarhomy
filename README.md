# 天气查询 Weather Inquiry

基于 **HarmonyOS Next (API 24 / 6.1.1)** 的天气查询应用。对接 [QWeather 和风天气](https://www.qweather.com/) 免费 API，支持实时天气、逐小时预报、7 天预报、环境数据、月相、日出日落等。

---

## 功能特性

| 模块 | 功能 |
|---|---|
| **实时天气** | 天气图标 · 温度 · 天气描述 · 体感温度 · 湿度 · 风向 · 风力 |
| **逐小时预报** | 横向滑动列表，展示未来 24 小时温度、降水概率、风向风力 |
| **7 天预报** | 日期标签 · 温差可视化指示条 · 日出日落时间 · 月相信息 |
| **环境数据** | AQI 空气质量指数（含颜色分级） · 紫外线 · 湿度 · 气压 · 能见度 · 风力风向 |
| **多城市管理** | Swiper 滑动切换 · 城市搜索 · 收藏/删除 · 右滑删除 |
| **自动定位** | GPS 定位 → 天气加载 · 降级回退北京 · 持续定位 + 5 km 阈值自动切换 |
| **天气背景** | 10 种天气主题背景图（晴/雨/雪/雷/雾/沙/风/多云/夜间/默认），自动昼夜切换 |
| **下拉刷新** | 手动手势刷新当前城市天气 |

---

## 快速开始

### 环境要求

- **DevEco Studio** ≥ 5.0.3
- **HarmonyOS SDK** API 24 (6.1.1)
- **targetDevice** 手机 (phone)

### 获取项目

```bash
git clone <你的仓库地址>
cd weather-inquiry
```

### 配置 API

复制模板并填入你的 [QWeather API 密钥](https://dev.qweather.com/)：

```bash
cp entry/src/main/ets/constants/AppConstants.example.ets \
   entry/src/main/ets/constants/AppConstants.ets
```

编辑 `AppConstants.ets`，修改以下两项：

```typescript
export const API_KEY = '你的QWeather密钥'
export const API_BASE = 'https://devapi.qweather.com'
```

> ⚠️ **注意**：`AppConstants.ets` 已被 `.gitignore` 排除，不会提交到仓库。每个开发者需自行创建。

### 构建运行

1. 用 DevEco Studio 打开项目根目录
2. 等待依赖同步完成（ohpm install）
3. 连接真机或启动模拟器
4. 点击 `Run 'entry'` 或 `Ctrl + F5`

---

## 项目结构

```
weather-inquiry/
├── entry/src/main/
│   ├── ets/
│   │   ├── api/
│   │   │   └── WeatherApi.ets          # HTTP 请求封装 · 6 个 QWeather API
│   │   ├── components/
│   │   │   ├── CurrentWeatherCard.ets   # 实时天气卡片
│   │   │   ├── ForecastList.ets         # 7 天预报列表（含温差条）
│   │   │   ├── HourlyForecast.ets       # 逐小时横向滑动预报
│   │   │   ├── EnvironmentCards.ets     # 环境数据网格（AQI/紫外线/湿度/风力）
│   │   │   ├── SunriseSetCard.ets       # 日出日落卡片
│   │   │   └── MoonCard.ets             # 月相卡片
│   │   ├── constants/
│   │   │   ├── AppConstants.ets         # 🔒 API 密钥与端点（不入库）
│   │   │   └── AppConstants.example.ets # API 配置模板
│   │   ├── entryability/
│   │   │   └── EntryAbility.ets         # Ability 入口
│   │   ├── model/
│   │   │   └── WeatherModel.ets         # 数据模型（6 个接口 + 5 个响应类型）
│   │   ├── pages/
│   │   │   ├── Index.ets                # 🏠 主页面（Swiper + Refresh）
│   │   │   └── SearchPage.ets           # 🔍 城市搜索与管理页
│   │   ├── services/
│   │   │   ├── LocationService.ets      # 定位服务（GPS + 持续监听）
│   │   │   └── FavoriteCityManager.ets  # 收藏城市持久化
│   │   └── utils/
│   │       └── WeatherUtils.ets         # 工具函数（格式化/图标/背景）
│   ├── module.json5                     # 模块配置（权限 · Ability）
│   └── resources/                       # 资源文件（图标 · 字符串）
├── build-profile.json5                  # 构建配置（签名 · SDK 版本）
├── .gitignore                           # Git 排除规则
└── README.md
```

---

## 技术架构

### 状态管理

使用 HarmonyOS **V2 状态管理**（`@ObservedV2` + `@Trace`）实现属性级精确更新：

```
CityWeatherState (@ObservedV2)
  ├── @Trace currentWeather      → CurrentWeatherCard
  ├── @Trace forecastDays        → ForecastList / SunriseSetCard / MoonCard
  ├── @Trace hourlyForecast      → HourlyForecast
  ├── @Trace airQuality          → EnvironmentCards
  └── @Trace cityIndex           → Swiper 当前页
```

仅 `@Trace` 标记的属性变化时才触发对应组件刷新，避免全量重渲染。

### 数据流

```
LocationService
      │ (GPS 坐标 / 降级北京)
      ▼
  WeatherApi.cityLookup()
      │ (cityId)
      ▼
  Promise.allSettled([
    WeatherApi.getCurrentWeather()
    WeatherApi.getForecast()
    WeatherApi.getHourlyForecast()
    WeatherApi.getAirQuality()
  ])
      │
      ▼
  CityWeatherState (@ObservedV2)
      │
      ▼
  各 UI 组件 (@Component + @Param/@Prop)
```

### API 接口

| 接口 | URL | 说明 |
|---|---|---|
| 城市搜索 | `/geo/v2/city/lookup` | 根据坐标/关键词查找城市 |
| 实时天气 | `/v7/weather/now` | 当前温度、天气、体感、风力 |
| 7 天预报 | `/v7/weather/7d` | 含日出日落、月相 |
| 逐小时预报 | `/v7/weather/24h` | 未来 24 小时 |
| 空气质量 | `/v7/air/now` | AQI + 污染物浓度（需付费订阅） |

### 权限声明

| 权限 | 用途 |
|---|---|
| `ohos.permission.INTERNET` | 网络请求 |
| `ohos.permission.LOCATION` | 精确定位 |
| `ohos.permission.APPROXIMATELY_LOCATION` | 模糊定位降级 |

---



## License

Apache-2.0 license

