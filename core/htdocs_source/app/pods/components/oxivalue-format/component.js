import Component from '@glimmer/component';
import { action } from '@ember/object';
import { getOwner } from '@ember/application';
import moment from "moment-timezone";

export default class OxivalueFormatComponent extends Component {
    get format() {
        return (this.args.content.format || "text");
    }

    get valueStr() {
        return (new String(this.args.content.value || "")).replace(/\r/gm, "");
    }

    get valueSplitByNewline() {
        return this.valueStr.split(/\n/);
    }

    get timestamp() {
        return (this.args.content.value > 0
            ? moment.unix(this.args.content.value).utc().format("YYYY-MM-DD HH:mm:ss UTC")
            : "---");
    }

    get styledValue() {
        let m = this.args.content.value.match(/^(([a-z]+):)?(.*)$/m);
        return {
            style: m[2],
            label: m[3],
        };
    }

    @action
    internalLinkClick(evt) {
        let element = evt.target;
        if (element.target !== "_blank") {
            evt.stopPropagation();
            evt.preventDefault();
            getOwner(this).lookup("route:openxpki").sendAjax({
                page: element.href.split("#")[1].replace(/\/openxpki\//, ""),
                target: element.target,
            });
        }
    }
}
