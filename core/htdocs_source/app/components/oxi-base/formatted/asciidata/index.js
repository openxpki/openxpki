import Component from '@glimmer/component'

/**
 * Shows ASCII data, e.g. a PEM block.
 *
 * ```html
 * <OxiBase::Formatted::Asciidata @value={{this.value}} />
 * ```
 *
 * @param { string | hash } value - the data.
 * @class OxiBase::Formatted::Asciidata
 */
export default class OxiFormattedAsciidataComponent extends Component {
    data
    filename

    constructor() {
        super(...arguments)

        let data
        if (Object.prototype.toString.call(this.args.value) === '[object Object]') {
            data = this.args.value.data
            this.filename = this.args.value.filename
        }
        else {
            data = this.args.value
        }

        this.data = (new String(data || '')).replace(/\r/gm, '')
    }
}
