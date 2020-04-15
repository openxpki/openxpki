import Component from '@glimmer/component';
import { action, computed } from '@ember/object';
import { getOwner } from '@ember/application';
import $ from 'jquery';
import types from './types';

export default class OxivalueFormatComponent extends Component {
    types = types;

    @action
    click(evt) {
        let target = evt.target;
        if (target.tagName === "A" && target.target !== "_blank") {
            evt.stopPropagation();
            evt.preventDefault();
            getOwner(this).lookup("route:openxpki").sendAjax({
                page: target.href.split("#")[1].replace(/\/openxpki\//, ""),
                target: target.target,
            });
        }
    }

    @computed("args.content.{format,value}")
    get formattedValue() {
        let htmlStr = this.types[this.args.content.format || "text"](this.args.content.value);
        let el = $('<div/>');
        // cleanup: remove all 'onXXX=' and 'javascript=' attributes and <script> elements
        el.html(htmlStr).find('*').each(function() {
            if (!$(this).attributes) return;
            let toStrip = $(this).attributes
                .filter(attr => (/^on/.test(attr.nodeName) || /javascript/.test(attr.value)))
                .map(attr => attr.nodeName);
            for (const name of toStrip) { $(this).removeAttribute(name) }
        });
        el.find('script').remove();
        return el.html();
    }
}
