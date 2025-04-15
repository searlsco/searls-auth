import { Controller } from '@hotwired/stimulus'

export default class SearlsAuthOtpController extends Controller {
  static targets = ['input']

  pasted (e) {
    const content = e.clipboardData?.getData('text')
    if (content && content.trim().match(/^\d{6}$/)) {
      this.inputTarget.value = content.trim()
      this.inputTarget.closest('form').requestSubmit()
    }
  }

  // Maybe not every design needs this but mine does: hide the caret if it's after the end of the max length
  caret () {
    const shouldHideCaret = this.inputTarget.maxLength === this.inputTarget.selectionStart &&
      this.inputTarget.maxLength === this.inputTarget.selectionEnd

    this.inputTarget.style.caretColor = shouldHideCaret ? 'transparent' : ''
  }
}
