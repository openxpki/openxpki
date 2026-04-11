import Component from '@glimmer/component';

const EMPTY_TILE = { type: 'empty', colspan: 1 };

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
 *       `'cards'`, ...) and a matching `content` object. An optional `colspan`
 *       { number } property makes the tile span that many columns (default: `1`).
 *     - `'newline'` to force a row break at that position
 *
 * @class OxiSection::Tiles
 * @extends Component
 */
export default class OxiSectionTilesComponent extends Component {
    // Returns an array of rows, each row padded to maxcol with empty tiles.
    // Splits on type:"newline" and enforces maxcol (default 4).
    // Each tile object is normalized to include a `colspan` property.
    get rows() {
        let tiles = this.args.def.tiles || [];
        let maxcol = this.maxcol;

        let rows = [];
        let currentRow = [];
        let currentWidth = 0;

        const flush = () => {
            const remaining = maxcol - currentWidth;
            if (remaining > 0) currentRow.push({ ...EMPTY_TILE, colspan: remaining });
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
            currentRow.push({ ...t, colspan });
            currentWidth += colspan;
            if (currentWidth >= maxcol) flush();
        }
        if (currentRow.length) flush();

        return rows;
    }

    get maxcol() {
        return this.args.def.maxcol ?? 4;
    }
}
