import Controller from '@ember/controller'
import { tracked } from '@glimmer/tracking'
import { action, set as emSet } from '@ember/object'
import { service } from '@ember/service'
import lite from 'caniuse-lite'
import { detect } from 'detect-browser'

export default class OpenXpkiController extends Controller {
    @service('oxi-content') content

    @action
    closePopup() {
        return this.content.closePopup()
    }
}