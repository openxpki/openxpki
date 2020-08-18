import Component from '@glimmer/component';
import { inject as injectCtrl } from '@ember/controller';

export default class ApplicationHeaderUserinfo extends Component {
    @injectCtrl openxpki; // injects OpenxpkiController
}
