'use strict'

export default function reducedAlphaColor(cssColor) {
    const div = document.createElement('div');
    div.id = 'for-computed-style';

    div.style.color = cssColor;

    // appending the created element to the DOM
    document.querySelector('body').appendChild(div);

    const match = getComputedStyle(div).color.match(/^rgba?\s*\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*(\d\.\d)\s*)?\)$/i);

    // removing element from the DOM
    document.querySelector('#for-computed-style').remove();

    if (match) {
        // match[0] is regex complete match (e.g. "rgb(0,0,0)"), not a regex capturing group
        let col = {
            r: match[1],
            g: match[2],
            b: match[3]
        };
        // if (match[4]) { // if alpha channel is present
        //     parsedColor.a = match[4];
        // }
        return `rgba(${col.r},${col.g},${col.b},0.1)`;
    } else {
        throw new Error(`Color ${cssColor} could not be parsed.`);
    }
}