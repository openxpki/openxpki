import Component from '@glimmer/component';

const EMPTY_TILE = { type: 'empty', colspan: 1 };

/**
 * Draw a grid of tiles, each rendered via {@link OxiSection}.
 *
 * ```html
 * <OxiSection::Tiles @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition.
 * @param { string } [def.label] - Section heading. Default: `""`
 * @param { string } [def.description] - Subheading shown below the label. Default: `""`
 * @param { number } [def.maxcol] - Maximum tiles per row. Default: `4`
 * @param { boolean } [def.border] - Render each tile as a card with a border. Default: `false`
 * @param { array } def.tiles - List of tile descriptors. Each entry is either:
 *   - A standard {@link OxiSection} definition with `type` set to any section
 *     type (`'button'`, `'keyvalue'`, `'form'`, `'grid'`, `'text'`, `'chart'`,
 *     `'cards'`, ...) and a matching `content` object. An optional `colspan`
 *     { number } property makes the tile span that many columns (default: `1`).
 *     An optional `border` { boolean } property overrides the section-level
 *     `border` setting for this tile: `true` forces a card border on, `false`
 *     forces it off, omitting the property inherits the section setting.
 *   - `'newline'` to force a row break at that position
 *
 * @class OxiSection::Tiles
 * @extends Component
 */
export default class OxiSectionTilesComponent extends Component {
    /**
     * Returns an array of rows, each padded to `maxcol` with empty tiles.
     * Splits on `"newline"` entries and enforces `maxcol`. Each tile object
     * is normalised to include a `colspan` and `_renderAsCard` property.
     * @memberOf OxiSection::Tiles
     */
    get rows() {
        let tiles = this.args.def.tiles || [];
        let maxcol = this.maxcol;
        const sectionBorder = !!this.args.def.border;

        // Resolve tri-state per-tile border: undefined = inherit, false = off, true = on
        const renderAsCard = (t) => {
            if (t.border === undefined || t.border === null) return sectionBorder;
            return !!t.border;
        };

        let rows = [];
        let currentRow = [];
        let currentWidth = 0;

        const flush = () => {
            const remaining = maxcol - currentWidth;
            if (remaining > 0) currentRow.push({ ...EMPTY_TILE, colspan: remaining, _renderAsCard: false });
            rows.push(currentRow);
            currentRow = [];
            currentWidth = 0;
        };

        for (const t of tiles) {
            if (t === 'newline' || t.type === 'newline') {
                if (currentRow.length) flush();
                continue;
            }
            const colspan = Math.min(t.colspan ?? 1, maxcol);
            if (currentWidth + colspan > maxcol) flush();
            currentRow.push({ ...t, colspan, _renderAsCard: renderAsCard(t) });
            currentWidth += colspan;
            if (currentWidth >= maxcol) flush();
        }
        if (currentRow.length) flush();

        return rows;
    }

    /**
     * Returns the maximum number of tile columns per row (default: `4`).
     * @memberOf OxiSection::Tiles
     */
    get maxcol() {
        return this.args.def.maxcol ?? 4;
    }
}
