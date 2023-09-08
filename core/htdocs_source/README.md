# OpenXPKI UI - An Ember.js application

The web frontend uses AJAX to retrieve structured data from the server and render pages using the Ember.js framework with the handlebars templating system.

This directory contains the UI source code, it cannot be used directly on your webserver.

## Container based development

#### Compilation

The OpenXPKI UI as an Ember.js application has to be compiled into plain JavaScript files ("bundles") after source code updates. This is done via  `ember-cli` but the easiest way is to use the supplied `Makefile` which in turn uses Docker/Podman.

```bash
make ember
```

#### Local npmjs.org cache

If the container repeatedly gets rebuilt it may need to reinstall the Node.js modules (e.g. if you do changes to the Docker build phase). In this case you may want to use the local npmjs.org cache server [verdaccio](https://verdaccio.org/). If it runs on your host on default port 4873 the Makefile detects it and configures `npm` to use the local cache.

To use _verdaccio_ run this in another terminal:

```bash
make npm-cache
```

#### Running the frontend

To run the UI you have to:

1. Start an OpenXPKI backend via Docker or Vagrant. It's expected to listen on https://localhost:8443

   > The Vagrant machine "develop" can be started as follows:
   >
   > ```bash
   > cd vagrant/develop
   > vagrant up && vagrant ssh
   > ```
   >
   > Then in the Vagrant machine:
   >
   > ```bash
   > sudo su
   > docker start mariadb && oxi-refresh
   > ```

2. Run the Ember.js based web UI incl. live reload (on code changes) via:

   ```bash
   make serve
   ```

3. Visit the web UI:

   - http://localhost:4200/webui/democa/

   - http://localhost:4200/webui/democa/#/test (component test page)

   - http://localhost:4200/webui/democa/tests (automated tests)


#### Help

There are several other targets in the Makefile which can be queried by running

```bash
make
```

## Host development stack

### Setup

If you prefer to have a full development stack on your machine you will need the following tools installed on your computer:

* [Git](https://git-scm.com/)
* [Node.js](https://nodejs.org/) via nvm (Node Version Manager)
* [Ember CLI](https://cli.emberjs.com/release/)
* other Node packages

**Node.js and pnpm**

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
cd core/htdocs_source
nvm install
npm install -g pnpm
pnpm config set auto-install-peers true
```

To continue developing later on the Node.js version has to be set:

```bash 
cd core/htdocs_source
nvm use
```

**Ember CLI and other global Tools**

```bash
pnpm install -g ember-cli ember-cli-update npm-check-updates
```

**Required Node.js modules**

```bash
pnpm install
```

### Development

**Compilation**

```bash
pnpm run build
```

**Running the frontend**

To run the Ember.js based web UI locally incl. live reload (on code changes) you have to start an OpenXPKI backend via Docker or Vagrant and then run:

```bash
pnpm run serve
```

(this calls `ember serve` and proxies AJAX requests to `$DEV_SERVER_FORWARD_TO`)

**Source code checks (aka. "linting")**

```bash
# Handlebars templates
pnpm run lint:hbs
pnpm run lint:hbs:fix
# JavaScript
pnpm run lint:js
pnpm run lint:js:fix
# CSS
pnpm run lint:css
pnpm run lint:css:fix
```

### Updates

**ember-cli**

Also see [the Ember CLI update guide](https://cli.emberjs.com/release/basic-use/upgrading/).

```bash
pnpm remove ember-cli ember-cli-update
pnpm install --save-dev ember-cli ember-cli-update
./node_modules/.bin/ember --version
```

**Ember app (config, dependencies etc.)**

```bash
nvm use
./node_modules/.bin/ember-cli-update
pnpm audit fix
# to install the modules on your host and update package-lock.json:
pnpm install
```

After this a rebuild needs to be done.

**Dependencies**

```bash
nvm use
# NOTE: the following command belongs to the package "npm-check-updates", not "ncu"!
ncu -u
# to install the modules on your host and update package-lock.json:
pnpm install
```

After this a rebuild needs to be done.

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

### Further Reading / Useful Links

* [ember.js](https://emberjs.com/)
* [ember-cli](https://cli.emberjs.com/release/)
* Development Browser Extensions
  * [ember inspector for chrome](https://chrome.google.com/webstore/detail/ember-inspector/bmdblncegkenkacieihfhpjfppoconhi)
  * [ember inspector for firefox](https://addons.mozilla.org/en-US/firefox/addon/ember-inspector/)
