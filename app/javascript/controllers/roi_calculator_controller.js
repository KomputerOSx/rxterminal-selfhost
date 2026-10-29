import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "bookingsSlider",
    "bookingsValue",
    "minutesSlider",
    "minutesValue",
    "wageSlider",
    "wageValue",
    "planSelect",
    "dailyTime",
    "monthlyTime",
    "monthlySavings",
    "roi",
    "barFill",
    "barPlanLabel",
    "barSavingsLabel",
    "calloutScenario",
    "calloutValue"
  ]

  static values = {
    workingDays: { type: Number, default: 22 },
    starterCost: Number,
    businessCost: Number
  }

  connect() {
    this.update()
  }

  update() {
    const bookings = parseInt(this.bookingsSliderTarget.value, 10)
    const minutes = parseInt(this.minutesSliderTarget.value, 10)
    const wage = parseFloat(this.wageSliderTarget.value)
    const planCost = this.#planCost()

    this.bookingsValueTarget.textContent = bookings.toLocaleString()
    this.minutesValueTarget.textContent = minutes
    this.wageValueTarget.textContent = `${this.#formatMoney(wage)}/hr`

    const dailyMinutes = bookings * minutes
    const monthlyMinutes = dailyMinutes * this.workingDaysValue
    const monthlyHours = monthlyMinutes / 60
    const monthlySavings = monthlyHours * wage
    const netSavings = monthlySavings - planCost
    const roiMultiplier = planCost > 0 ? monthlySavings / planCost : 0

    this.dailyTimeTarget.textContent = this.#formatDuration(dailyMinutes)
    this.monthlyTimeTarget.textContent = this.#formatDuration(monthlyMinutes, true)
    this.monthlySavingsTarget.textContent = this.#formatMoney(monthlySavings)
    this.roiTarget.textContent = `${this.#formatMultiplier(roiMultiplier)}×`

    const savingsShare = monthlySavings > 0 ? Math.min(planCost / monthlySavings, 1) : 0
    this.barFillTarget.style.width = `${savingsShare * 100}%`
    this.barPlanLabelTarget.textContent = this.#formatMoney(planCost)
    this.barSavingsLabelTarget.textContent = this.#formatMoney(monthlySavings)

    const planName = this.planSelectTarget.selectedOptions[0].textContent.trim()
    this.calloutScenarioTarget.textContent =
      `${bookings} bookings/day · ${minutes} min saved · ${this.#formatMoney(wage)}/hr · ${planName}`
    this.calloutValueTarget.textContent = this.#formatMoney(Math.max(netSavings, 0))
  }

  #planCost() {
    const planKey = this.planSelectTarget.value
    const cents = planKey === "starter" ? this.starterCostValue : this.businessCostValue
    return cents / 100
  }

  #formatMoney(amount) {
    return new Intl.NumberFormat("en-GB", {
      style: "currency",
      currency: "GBP",
      minimumFractionDigits: amount % 1 === 0 ? 0 : 2,
      maximumFractionDigits: 2
    }).format(amount)
  }

  #formatDuration(totalMinutes, compact = false) {
    const hours = Math.floor(totalMinutes / 60)
    const minutes = totalMinutes % 60

    if (compact && minutes === 0) {
      return `${hours.toLocaleString()} hrs`
    }

    if (hours === 0) {
      return `${minutes} min`
    }

    if (minutes === 0) {
      return `${hours.toLocaleString()} hrs`
    }

    return `${hours.toLocaleString()}h ${minutes}m`
  }

  #formatMultiplier(value) {
    if (value >= 10) {
      return Math.round(value).toString()
    }

    return value.toFixed(1)
  }
}
