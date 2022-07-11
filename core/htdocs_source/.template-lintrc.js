// configuration for ember-template-lint, called via 'npm run lint:hbs'
module.exports = {
  extends: 'recommended',

  rules: {
    // complain about bare strings
    'no-bare-strings': true,
    // don't complain about HTML comments
    'no-html-comments': 'off',
    // Our complex form system does not allow for input labels everywhere
    'require-input-label': 'off',
  }
}
