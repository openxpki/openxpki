# OpenXPKI UI - An Ember.js application

The web UI uses AJAX to retrieve structured data from the server and render
the pages using the Ember.js framework with the handlebars templating system.

This directory contains the UI source code, it cannot be used directly on your
webserver.

## Ember.js

Ember.js applications are compiled into JavaScript files ("bundles"). After
making modifications the source code has to be recompiled via `ember-cli`.

The easiest way to do that after some code updates is to use the supplied
`Makefile` (which in turn uses Docker to compile the whole UI):

```bash
make ember
```

For a full development stack on your machine please use the following
instructions.

## Development stack

You will need the following things properly installed on your computer.

* [Git](https://git-scm.com/)
* [Node.js](https://nodejs.org/) (with npm)
* [Ember CLI](https://cli.emberjs.com/release/)
* [Google Chrome](https://google.com/chrome/) for unit tests

### Node.js

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
cd core/htdocs_source
nvm install
```

### Ember CLI and other global Tools

```bash
nvm use
pnpm install -g ember-cli ember-cli-update npm-check-updates
```

## Installation of required Node.js modules

```bash
nvm use
pnpm install
```

## Running / Development

To run the web UI locally you have to:

1. Start an OpenXPKI backend via Docker or Vagrant. It's expected to listen on localhost:8443
2. Now run the Ember based web UI with live reload (on code changes) via:
   `pnpm run serve` (this calls "ember serve ..." and proxies AJAX requests to localhost:8443)
3. Visit the web UI at [http://localhost:4200/openxpki/#/](http://localhost:4200/openxpki/#/).
4. Visit tests at [http://localhost:4200/openxpki/#/test](http://localhost:4200/openxpki/#/test).

### Linting

```bash
nvm use
# Handlebars templates and JavaScript
pnpm run lint
pnpm run lint:fix
# only Handlebars templates
pnpm run lint:hbs
pnpm run lint:hbs:fix
# only JavaScript
pnpm run lint:js
pnpm run lint:js:fix
```

### Build Ember app

####  Using Docker

```bash
make ember
```

#### Verdaccio (local npmjs.org cache)

If the container repeatedly gets rebuilt it may need to reinstall the NPM modules (e.g. if you do changes to the Docker build phase). In this case you may want to use the local npmjs.org cache server [verdaccio](https://verdaccio.org/). If it runs on your host on default port 4873 the Makefile should detect it and configures `npm` during container building to use the local cache.

To use _verdaccio_ run these steps:

```bash
nvm use
pnpm install -g verdaccio
nvm exec verdaccio -l 0.0.0.0:4873
```

#### On your host machine

```bash
nvm use
pnpm run build
```

### Update ember-cli

Also see [the Ember CLI update guide](https://cli.emberjs.com/release/basic-use/upgrading/).

```bash
nvm use
pnpm remove ember-cli ember-cli-update
pnpm install --save-dev ember-cli ember-cli-update
./node_modules/.bin/ember --version
```

### Update the Ember app (config, dependencies etc.)

```bash
nvm use
./node_modules/.bin/ember-cli-update
pnpm audit fix
# to install the modules on your host and update package-lock.json:
pnpm install
```

After this a [rebuild](#build-production) needs to be done.

### Update dependencies

```bash
nvm use
# NOTE: the following command belongs to the package "npm-check-updates", not "ncu"!
ncu -u
# to install the modules on your host and update package-lock.json:
pnpm install
```

After this a [rebuild](#build-production) needs to be done.

### Run tests

1. Start the OpenXPKI server on port 8443, e.g. via Vagrant machine "develop"

   > The Vagrant machine can be started as follows:
   >
   > ```bash
   > cd vagrant/develop
   > vagrant up && vagrant ssh
   > ```
   > Then in the Vagrant machine:
   > ```bash
   > sudo su
   > docker start mariadb && openxpkictl start
   > ```

2. Start the Ember development server:

   ```bash
   make serve

   ## The following currently fails for unknown reasons:
   # ember test
   # ember test --server
   ```

3. Now in your browser open http://localhost:4200/openxpki/tests

## Notes

### Directory layout

Ember.js as of 2023-09-07 knows three different layouts which can (and are) used
in parallel:

1. Deprecated pre-Octane layout with separated component template and controller
2. Classic layout with co-location (of component controller and template)
3. POD layout

For better code grouping we use a mixture:

* Classic layout for **components** (to separate them from the routes. Also, as of 2023-09-07 `@embroider` does not seem to support POD layout components)
* Classic layout for **services** (to separate them from the routes)
* POD layout for **routes** incl. their controllers and templates (to have all related files in one directory per route)

### Inheriting template from parent component

Please note that currently (Ember 3.20.3) inheriting the template does not work:

```javascript
import OxiFieldRawtextComponent from '../rawtext/component';
import OxiFieldRawtextTemplate from '../rawtext/template';

export default class OxiFieldTextComponent extends OxiFieldRawtextComponent {
    layout OxiFieldRawtextTemplate;

    @action
    onInput(event) {
        this.args.onChange(event.target.value);
    }
}
```

## Further Reading / Useful Links

* [ember.js](https://emberjs.com/)
* [ember-cli](https://cli.emberjs.com/release/)
* Development Browser Extensions
  * [ember inspector for chrome](https://chrome.google.com/webstore/detail/ember-inspector/bmdblncegkenkacieihfhpjfppoconhi)
  * [ember inspector for firefox](https://addons.mozilla.org/en-US/firefox/addon/ember-inspector/)
