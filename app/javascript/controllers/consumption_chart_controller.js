import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    labels: Array,
    values: Array
  }

  connect() {
    console.log("Chart controller connected")
    if (typeof window.Chart !== 'undefined') {
      this.initChart()
    } else {
      console.error("Chart.js n'est pas disponible")
    }
  }

  initChart() {
    try {
      const ctx = this.canvasTarget.getContext('2d')
      this.chart = new window.Chart(ctx, {
        type: 'bar',
        data: {
          labels: this.labelsValue,
          datasets: [{
            label: 'Consommation (kWh)',
            data: this.valuesValue,
            backgroundColor: 'rgba(79, 70, 229, 0.2)',
            borderColor: 'rgba(79, 70, 229, 1)',
            borderWidth: 1
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false
        }
      })
    } catch (error) {
      console.error("Error initializing chart:", error)
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
}
