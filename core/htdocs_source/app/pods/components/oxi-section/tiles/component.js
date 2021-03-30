import Component from '@glimmer/component';
import { computed } from '@ember/object';

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
            result.push(t);
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
