import { Controller } from '@hotwired/stimulus'

export default class SearlsAuthLoginController extends Controller {
  static values = {
    email: String,
    emailFieldName: {
      type: String,
      default: 'email'
    },
    timeZoneFieldName: {
      type: String,
      default: 'time_zone'
    }
  }

  connect () {
    this.emailValue = window.sessionStorage.getItem('__searls_auth_email') || undefined
    if (this.emailValue) {
      this.element.querySelector(`[name=${this.emailFieldNameValue}]`).value = this.emailValue
    }

    this.#setTimeZoneFieldMaybe()
  }

  updateEmail (e) {
    this.emailValue = e.currentTarget.value
    window.sessionStorage.setItem('__searls_auth_email', this.emailValue)
  }

  #setTimeZoneFieldMaybe () {
    const hiddenField = this.element.querySelector(`[name=${this.timeZoneFieldNameValue}]`)
    if (hiddenField) {
      hiddenField.value ||= Intl.DateTimeFormat().resolvedOptions().timeZone
    }
  }
}
