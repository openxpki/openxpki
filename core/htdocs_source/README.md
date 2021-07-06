# OpenXPKI UI - An Ember.js application

The web UI uses AJAX to retrieve structured data from the server and render
the pages using the Ember.js framework with the handlebars templating system.

This directory contains the developer code of the UI, this MUST NOT go onto
your webserver.

## Ember.js

Ember.js applications are compiled into single JavaScript files ("bundles").
After making modifications the source code has to be recompiled by `ember-cli`.

The easiest way to do that if you just updated some code is via the supplied
`Makefile` which uses Docker to compile the whole UI code:

```bash
make
```

For a full development stack on your machine please use the following
instructions.

## Development stack

You will need the following things properly installed on your computer.

* [Git](https://git-scm.com/)
* [Node.js](https://nodejs.org/) (with npm)
* [Ember CLI](https://ember-cli.com/)
* ([Google Chrome](https://google.com/chrome/) for unit tests)

### Node.js

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
cd core/htdocs_source
nvm install
```

### Ember CLI and other global Tools

```bash
nvm use
npm install -g ember-cli ember-cli-update npm-check-updates
```

## Installation of required Node.js modules

```bash
nvm use
npm install
```

## Running / Development

To run the web UI locally you have to:

1. Start an OpenXPKI backend via Docker or Vagrant. It's expected to listen on localhost:8443
2. Now run the Ember based web UI with live reload (on code changes) via:
   `npm run serve` (this calls "ember serve ..." and proxies AJAX requests to localhost:8443)
3. Visit the web UI at [http://localhost:4200/openxpki/#/](http://localhost:4200/openxpki/#/).
4. Visit tests at [http://localhost:4200/openxpki/#/test](http://localhost:4200/openxpki/#/test).

### Linting

```bash
nvm use
npm run lint:hbs
npm run lint:js
npm run lint:js -- --fix
```

### Build (production)

```bash
make
# or manually:
nvm use
npm run build
```

### Updating ember-cli

```bash
nvm use
ember-cli-update
npm audit fix
npm dedupe
# to install the modules on your host and update package-lock.json:
npm install
```

After this a [rebuild](#build-production) needs to be done.

### Updating dependencies

```bash
nvm use
ncu -u
# to install the modules on your host and update package-lock.json:
npm install
```

After this a [rebuild](#build-production) needs to be done.

### Running Tests (currently not used)

```bash
nvm use
ember test
ember test --server
```

## Further Reading / Useful Links

* [ember.js](https://emberjs.com/)
* [ember-cli](https://ember-cli.com/)
* Development Browser Extensions
  * [ember inspector for chrome](https://chrome.google.com/webstore/detail/ember-inspector/bmdblncegkenkacieihfhpjfppoconhi)
  * [ember inspector for firefox](https://addons.mozilla.org/en-US/firefox/addon/ember-inspector/)
