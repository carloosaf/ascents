import ChartBundle from "../../vendor/chart.umd.js"

const Chart = ChartBundle.Chart || ChartBundle.default || ChartBundle

const cssVar = (name, fallback) => {
  const value = getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  return value || fallback
}

const palette = () => [
  cssVar("--ascents-action", "#14b8a6"),
  cssVar("--ascents-tape", "#d9ff3f"),
  cssVar("--grade-blue", "#60a5fa"),
  cssVar("--grade-pink", "#f472b6"),
  cssVar("--ascents-clay", "#e07a5f"),
  cssVar("--grade-purple", "#a78bfa"),
  cssVar("--grade-yellow", "#facc15"),
  cssVar("--grade-red", "#fb7185"),
]

const parseConfig = (el) => {
  try {
    return JSON.parse(el.dataset.chart || "{}")
  } catch (_error) {
    return {}
  }
}

const baseOptions = () => ({
  responsive: true,
  maintainAspectRatio: false,
  interaction: {intersect: false, mode: "index"},
  plugins: {
    legend: {
      labels: {color: cssVar("--ascents-chalk-soft", "#c6ccd5"), boxWidth: 12},
    },
    tooltip: {
      backgroundColor: cssVar("--ascents-panel-deep", "#11151d"),
      borderColor: cssVar("--ascents-line", "#2a323d"),
      borderWidth: 1,
      titleColor: cssVar("--ascents-chalk", "#f4f7f2"),
      bodyColor: cssVar("--ascents-chalk-soft", "#c6ccd5"),
      displayColors: false,
    },
  },
})

const axisOptions = () => ({
  scales: {
    x: {
      grid: {color: "rgba(154, 164, 178, 0.12)"},
      ticks: {color: cssVar("--ascents-muted", "#9aa4b2")},
    },
    y: {
      beginAtZero: true,
      grid: {color: "rgba(154, 164, 178, 0.12)"},
      ticks: {color: cssVar("--ascents-muted", "#9aa4b2"), precision: 0},
    },
  },
})

const datasetFor = (config) => {
  const colors = palette()

  if (config.type === "line") {
    return {
      label: config.label,
      data: config.values,
      borderColor: cssVar("--ascents-action", "#14b8a6"),
      backgroundColor: "rgba(20, 184, 166, 0.16)",
      pointBackgroundColor: cssVar("--ascents-tape", "#d9ff3f"),
      pointBorderColor: cssVar("--ascents-panel-deep", "#11151d"),
      pointHoverRadius: 5,
      pointRadius: 3,
      fill: true,
      tension: 0.35,
    }
  }

  return {
    label: config.label,
    data: config.values,
    backgroundColor: config.values.map((_value, index) => colors[index % colors.length]),
    borderColor: cssVar("--ascents-panel", "#171c24"),
    borderWidth: config.type === "doughnut" ? 2 : 0,
    borderRadius: config.type === "bar" ? 6 : 0,
  }
}

const optionsFor = (config) => {
  const options = baseOptions()

  if (config.type === "doughnut") {
    options.cutout = "62%"
    options.plugins.legend.position = "bottom"
  } else {
    Object.assign(options, axisOptions())
    options.plugins.legend.display = false
  }

  return options
}

const StatsChart = {
  mounted() {
    this.draw = () => {
      const config = parseConfig(this.el)
      const canvas = this.el.querySelector("canvas")

      if (!canvas || !config.type) return

      this.chart?.destroy()
      this.chart = new Chart(canvas, {
        type: config.type,
        data: {
          labels: config.labels || [],
          datasets: [datasetFor(config)],
        },
        options: optionsFor(config),
      })
    }

    this.handleThemeChange = () => this.draw()
    window.addEventListener("phx:set-theme", this.handleThemeChange)
    window.addEventListener("storage", this.handleThemeChange)
    this.draw()
  },

  updated() {
    this.draw()
  },

  destroyed() {
    window.removeEventListener("phx:set-theme", this.handleThemeChange)
    window.removeEventListener("storage", this.handleThemeChange)
    this.chart?.destroy()
  },
}

export default StatsChart
