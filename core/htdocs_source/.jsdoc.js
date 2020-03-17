'use strict';

module.exports = {
    source: {
        includePattern: ".+\\.js(doc|x)?$",
        excludePattern: "((^|\\/|\\\\)_)|(node_modules)|^dist|^dist-dev",
    },
    opts: {
        source: "app",
        recurse: true,
        destination: "./docs-api/",
    },
    plugins: ['plugins/markdown'],
    markdown: {
        hardwrap: true,
        idInHeadings: true,
    }
};
