import Component from '@glimmer/component'
import Button from 'openxpki/data/button'

/**
 * Draws cards.
 *
 * @param { hash } def - card section definition
 * ```javascript
 * {
 *      label: 'Realms',
 *      description: 'Please choose a realm',
 *      vertical: true, // optional, default: false
 *      cards: [
 *          {
 *              label: 'Demo-CA',
 *              description: "The demo CA",
 *              footer: 'Auto-Login',
 *              image: 'data:image/webp;base64,UklGRsIdAAB...',
 *              href: '/demo-ca/',
 *          },
 *          {
 *              ...
 *              page: 'workflow!one',
 *          },
 *          ...
 *      ],
 * }
 * ```
 * @class OxiSectionCardsComponent
 * @extends Component
 */
export default class OxiSectionCardsComponent extends Component {
    get cards() {
        let cards = this.args.def.cards || []
        // inject _button property
        cards.forEach(c => c._button = Button.fromHash({
            format: c.format,
            href: c.href,
            target: c.target,
            page: c.page,
            action: c.action,
            disabled: c.disabled,
            confirm: c.confirm,
            onClick: c.onClick,
        }))
        return cards
    }
}
