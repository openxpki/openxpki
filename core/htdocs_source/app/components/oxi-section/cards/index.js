import Component from '@glimmer/component'
import Clickable from 'openxpki/data/clickable'

/**
 * Render big clickable bordered buttons with optional image and description
 * horizontally or vertically.
 *
 * ```html
 * <OxiSection::Cards @def={{this.def}} />
 * ```
 *
 * @param { object } def - Card section definition.
 * @param { boolean } [def.vertical] - Stack cards vertically instead of horizontally. Default: `false`
 * @param { array } def.cards - List of card descriptors.
 * @param { string } def.cards[].label - Card title.
 * @param { string } [def.cards[].description] - Card body text.
 * @param { string } [def.cards[].footer] - Text shown in the card footer.
 * @param { string } [def.cards[].image] - Data URL or URL of an image shown in the card.
 * @param { string } [def.cards[].color] - CSS background color of the card.
 * @param { string } [def.cards[].css_class] - Extra CSS class added to the card element.
 * @param { string } [def.cards[].href] - URL to open on click.
 * @param { string } [def.cards[].page] - OpenXPKI page to load on click.
 * ```javascript
 * {
 *      label: 'Realms',
 *      description: 'Please choose a realm',
 *      vertical: true,
 *      cards: [
 *          {
 *              label: 'Demo-CA',
 *              description: "The demo CA",
 *              footer: 'Auto-Login',
 *              image: 'data:image/webp;base64,UklGRsIdAAB...',
 *              href: '/demo-ca/',
 *              color: '#BEB',
 *              css_class: '',
 *          },
 *          { ..., page: 'workflow!one' },
 *      ],
 * }
 * ```
 * @class OxiSection::Cards
 * @extends Component
 */
export default class OxiSectionCardsComponent extends Component {
    /**
     * Returns the card list with a `_clickable` property ({@link Clickable}) injected
     * into each card for use by the template.
     * @memberOf OxiSection::Cards
     */
    get cards() {
        let cards = this.args.def.cards || []
        // inject _clickable property
        cards.forEach(c => c._clickable = Clickable.fromHash({
            format: 'card', // will be ignored by OxiButton if c.css_class is set
            ...c,
        }))
        return cards
    }
}
