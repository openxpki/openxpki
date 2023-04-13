'use strict';

module.exports = {
    source: {
        includePattern: ".+\\.js(doc|x)?$",
        excludePattern: "((^|\\/|\\\\)_)|(node_modules)|^dist|^dist-dev",
    },
    opts: {
        recurse: true,
        destination: "/docs-api", // directory in Docker container
    },
    plugins: ['plugins/markdown'],
    markdown: {
        hardwrap: false,
        idInHeadings: true,
    }
};
