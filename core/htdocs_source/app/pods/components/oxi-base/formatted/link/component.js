import Component from '@glimmer/component';
import { action } from '@ember/object';
import { inject } from '@ember/service';

export default class OxiFormattedLinkComponent extends Component {
    @inject('oxi-content') content;

    @action
    internalLinkClick(event) {
        let target = this.args.spec.target || "popup";

        // ignore links with _blank target
        if (target === "_blank") return true;

        // perform AJAX request instead of opening URL
        event.stopPropagation();
        event.preventDefault();
        this.content.updateRequest({
            page: this.args.spec.page,
            target: target,
        });
    }
}
