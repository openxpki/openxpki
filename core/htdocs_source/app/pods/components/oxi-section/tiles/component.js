import Component from '@glimmer/component';
import { computed } from '@ember/object';

/**
 * Draws tiles.
 *
 * @param { hash } def - section definition
 * ```javascript
 * {
 *      label: 'Actions',
 *      description: 'Please choose an action',
 *      maxcol => 4, // maximum tiles per row (optional, default: maximum according to browser window)
 *      align => 'left', // or 'center' or 'right' (optional, default: 'left')
 *      tiles => [
 *          {
 *              type: 'button', content => { ... },
 *          },
 *          {
 *              type: 'newline',
 *          },
 *          {
 *              type: 'button', content => { ... },
 *          },
 *      ],
 * }
 * ```
 * @module component/oxi-section/tiles
 */
export default class OxiSectionTilesComponent extends Component {
    @computed("args.def.tiles")
    get tiles() {
        let tiles = this.args.def.tiles || [];
        let maxcol = this.args.def.maxcol;

        if (! maxcol) return tiles;

        // insert a newline after maxcol columns
        let result = [];
        let newline = { type: 'newline' };

        let col = 0;
        for (const t of tiles) {
            if (++col > maxcol) {
                result.push(newline);
                col = 0;
            }

            let newTile = { ...t };

            if (t.type == 'newline') {
                col = 0;
            } else {
                newTile.content ||= {};
                newTile.content.format = 'tile'; // button format
            }
            result.push(newTile);
        }
        return result;
    }

    @computed("args.def.align")
    get align() {
        let defaultAlign = 'left';
        let align = this.args.def.align || defaultAlign;
        return align.match(/^(left|right|center)$/) ? align : defaultAlign;
    }
}
