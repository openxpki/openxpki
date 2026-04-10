import Component from '@glimmer/component'

export default class OxiSectionButtonComponent extends Component {
    get button() {
        return {
            format: 'tile',
            ...this.args.def,
        }
    }
}
