import Controller, { inject as injectCtrl } from '@ember/controller'
import { alias } from '@ember/object/computed'

export default Controller.extend
    openxpki: injectCtrl()      # injects OpenxpkiController
    user: alias "openxpki.model.user"
