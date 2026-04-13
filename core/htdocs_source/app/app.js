import 'bootstrap'; // Bootstrap JS — initialises data-API event delegation (Dropdown, Modal, etc.)
import './styles/app.scss';
import Application from '@ember/application';
import Resolver from 'ember-resolver';
import loadInitializers from 'ember-load-initializers';
import config from "./config/environment";

// Embroider+Vite requires explicit wiring that classic builds did automatically:
// - compatModules: static manifest of all app modules, replacing classic runtime filesystem scanning
// - setupInspector: connects the Ember Inspector browser devtools extension
import setupInspector from "@embroider/legacy-inspector-support/ember-source-4.12";
import compatModules from "@embroider/virtual/compat-modules";

/**
 * Root Ember application class. Wires the resolver, compat modules, and the
 * Ember Inspector devtools extension.
 *
 * @class App
 * @extends Application
 */
export default class App extends Application {
  modulePrefix = config.modulePrefix;
  podModulePrefix = config.podModulePrefix;
  Resolver = Resolver.withModules(compatModules);
  inspector = setupInspector(this);
}

loadInitializers(App, config.modulePrefix, compatModules);
