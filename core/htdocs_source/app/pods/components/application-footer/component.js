import Component from '@glimmer/component';
import ENV from 'openxpki/config/environment';

export default class OxiApplicationFooter extends Component {
    get envBuildYear() {
        return ENV.buildYear;
    }
}
