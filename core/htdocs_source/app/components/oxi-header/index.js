import Component from '@glimmer/component'
import { service } from '@ember/service'

/**
 * Application header bar. Renders a logo/title row and the {@link OxiHeader::UserInfo}
 * panel.
 *
 * Takes no arguments; all data is read from the {@link service/oxi-config} and {@link service/oxi-content} services.
 *
 * @class OxiHeader
 * @extends Component
 */
export default class ApplicationHeader extends Component {
    @service('oxi-config') config
    @service('oxi-content') content
}
