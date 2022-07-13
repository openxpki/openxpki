// configuration for ember-template-lint, called via 'npm run lint:hbs'
module.exports = {
  extends: 'recommended',

  rules: {
    // complain about bare strings
    'no-bare-strings': true,
    // don't complain about HTML comments
    'no-html-comments': 'off',
    // our complex form system does not allow for input labels everywhere
    'require-input-label': 'off',
    // not using keydown but keyup e.g. for ESCape or arrow keys would lead to unpleasant delays
    'no-down-event-binding': 'off',
  }
}
