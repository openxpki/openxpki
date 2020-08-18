import Component from '@glimmer/component';
import { action } from '@ember/object';
import { getOwner } from '@ember/application';

export default class OxiFormattedLinkComponent extends Component {
    @action
    internalLinkClick(event) {
        let target = this.args.spec.target || "popup";

        // ignore links with _blank target
        if (target === "_blank") return true;

        // perform AJAX request instead of opening URL
        event.stopPropagation();
        event.preventDefault();
        getOwner(this).lookup("route:openxpki").sendAjax({
            page: this.args.spec.page,
            target: target,
        });
    }
}
