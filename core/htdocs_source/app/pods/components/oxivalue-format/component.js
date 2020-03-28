import Component from '@ember/component';
import { getOwner } from '@ember/application';
import $ from "jquery";
import types from "./types";

const OxivalueFormatComponent = Component.extend({
    onAnchorClick: Em.on("click", function(evt) {
        let target = evt.target;
        if (target.tagName === "A" && target.target !== "_blank") {
            evt.stopPropagation();
            evt.preventDefault();
            getOwner(this).lookup("route:openxpki").sendAjax({
                page: target.href.split("#")[1].replace(/\/openxpki\//, ""),
                target: target.target,
            });
        }
    }),
    types: types,
    formatedValue: Em.computed("content.format", "content.value", function() {
        let htmlStr = this.get("types")[this.get("content.format") || "text"](this.get("content.value"));
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
    })
});

export default OxivalueFormatComponent;