import Controller, { inject as injectCtrl } from '@ember/controller';
import { alias } from '@ember/object/computed';
import { action } from "@ember/object";

export default class ApplicationController extends Controller {
    @injectCtrl openxpki; // injects OpenxpkiController
    @alias("openxpki.model.user") user;

    @action removeLoader() {
        $(".waiting-for-ember").remove();
    }
}