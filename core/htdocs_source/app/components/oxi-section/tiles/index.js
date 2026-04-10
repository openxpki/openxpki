import Component from '@glimmer/component';

const EMPTY_TILE = { type: 'empty' };

/**
 * Draws a grid of tiles, each rendered via `OxiSection`.
 *
 * ```html
 * <OxiSection::Tiles @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition:
 *   - `label` { string } - Section heading. Default: `""`
 *   - `description` { string } - Subheading shown below the label. Default: `""`
 *   - `maxcol` { number } - Maximum tiles per row. Default: `4`
 *   - `borders` { boolean } - Render each tile as a card with a border. Default: `false`
 *   - `tiles` { array } - List of tile descriptors. Each entry is either:
 *     - A standard `OxiSection` definition with `type` set to any section
 *       type (`'button'`, `'keyvalue'`, `'form'`, `'grid'`, `'text'`, `'chart'`,
 *       `'cards'`, ...) and a matching `content` object, or
 *     - `'newline'` to force a row break at that position
 *
 * @class OxiSection::Tiles
 * @extends Component
 */
export default class OxiSectionTilesComponent extends Component {
    // Returns an array of rows, each row padded to maxcol with empty tiles.
    // Splits on type:"newline" and enforces maxcol (default 4).
    get rows() {
        let tiles = this.args.def.tiles || [];
        let maxcol = this.maxcol;

        let rows = [];
        let currentRow = [];

        const flush = () => {
            while (currentRow.length < maxcol) currentRow.push(EMPTY_TILE);
            rows.push(currentRow);
            currentRow = [];
        };

        for (const t of tiles) {
            if (t === 'newline' || t.type === 'newline') {
                if (currentRow.length) flush();
                continue;
            }
            if (currentRow.length >= maxcol) flush();
            currentRow.push(t);
        }
        if (currentRow.length) flush();

        return rows;
    }

    get maxcol() {
        return this.args.def.maxcol ?? 4;
    }
}
