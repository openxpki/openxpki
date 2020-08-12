import Route from '@ember/routing/route';
import { tracked } from '@glimmer/tracking';
import { later, cancel } from '@ember/runloop';
import { Promise } from 'rsvp';
import { set as emSet } from '@ember/object';
import { inject as service } from '@ember/service';
import { debug } from '@ember/debug';
import $ from "jquery";

class Content {
    @tracked user = null;
    @tracked page = null;
    @tracked ping = null;
    @tracked refresh = null;
    @tracked structure = null;
    @tracked rtoken = null;
    @tracked status = null;
    @tracked popup = null;
    @tracked tabs = [];
    @tracked navEntries = [];
    @tracked error = null;
    @tracked isLoading = false;
}

export default class OpenXpkiRoute extends Route {
    @service('oxi-config') oxiConfig;
    @service('oxi-locale') oxiLocale;
    @service('intl') intl;

    // Reserved Ember property "queryParams"
    // https://api.emberjs.com/ember/3.17/classes/Route/properties/queryParams?anchor=queryParams
    queryParams = {
        // refreshModel==true causes an "in-place" transition, so the model
        // hooks for this route (and any child routes) will re-fire
        startat:  { refreshModel: true },
        limit:    { refreshModel: true },
        force:    { refreshModel: true },
    };
    needReboot = ["login", "logout", "login!logout", "welcome"];

    @tracked content = new Content();

    // Reserved Ember function
    beforeModel(transition) {
        let queryParams = transition.to.queryParams;
        let modelId = transition.to.params.model_id;
        debug("openxpki/route - beforeModel: model_id = " + modelId);

        // "force" is only evaluated above using "refreshModel: true"
        if (queryParams.force) {
            delete queryParams.force;
        }

        let structureIfNeeded; // chain of ajax calls via Promises

        /*
         * load base page structure first first time or for special pages ("needReboot")
         */
        if (!this.content.navEntries.length || this.needReboot.indexOf(modelId) >= 0) {
            // don't send request yet, only create a lambda via arrow function expression
            structureIfNeeded = () => {
                return this.sendAjax({
                    page: "bootstrap!structure",
                    baseurl: window.location.pathname,
                });
            };
        }
        else {
            structureIfNeeded = () => { Promise.resolve() };
        }

        /*
         * load requested page part
         */
        let request = {
            page: modelId
        };
        if (queryParams.limit) { request.limit = queryParams.limit }
        if (queryParams.startat) { request.startat = queryParams.startat }

        // load as top content if 'modelId' is part of navigation or in 'needReboot' list
        let flatList = this.content.navEntries.reduce((p, n) => p.concat(n, n.entries || []), []);
        if (flatList.findBy("key", modelId) || this.needReboot.indexOf(modelId) >= 0) {
            request.target = "top";
        }
        return this.oxiConfig.ready // localconfig.js might change rootURL, so first thing is to query it
            .then( () => structureIfNeeded() )
            .then( () => this.sendAjax(request) );
    }

    // Reserved Ember function
    model(params/*, transition*/) {
        this.content.page = params.model_id; this.updateNavEntryActiveState(this.content);
        return this.content;
    }

    doPing(cfg) {
        this.content.ping = later(this, () => {
            $.ajax({ url: cfg.href });
            return this.doPing(cfg);
        }, cfg.timeout);
    }

    setLoadingState(isLoading) {
        // note that we cannot use the Ember "loading" event as this would only
        // trigger on route changes, but not if we do sendAjax()
        if (isLoading) {
            // remove focus from button to prevent user from doing another
            // submit by hitting enter
            document.activeElement.blur();
        }
        this.content.isLoading = isLoading;
    }

    sendAjax(request) {
        this.setLoadingState(true);
        debug("openxpki/route - sendAjax: page = " + request.page);
        // assemble request parameters
        let req = {
            data: {
                ...request,
                "_": new Date().getTime(),
            },
            dataType: "json",
            type: request.action ? "POST" : "GET",
            url: this.oxiConfig.backendUrl,
        };
        if (req.type === "POST") {
            req.data._rtoken = this.content.rtoken;
        }

        // Fetch "targetElement" parameter for use in AJAX response handler later on.
        // Pseudo-target "self" is transformed so new content will be shown in the
        // currently active place: a modal popup, an active tab or on top (i.e. single hidden tab)
        let targetElement = req.data.target || "self";
        if (targetElement === "modal") targetElement = "popup"; // legacy naming
        if (targetElement === "self") {
            if (this.content.popup) { targetElement = "popup" }
            else if (this.content.tabs.length > 1) { targetElement = "active" }
            else { targetElement = "top" }
        }

        if (this.content.refresh) {
            cancel(this.content.refresh);
            this.content.refresh = null;
        }

        /* eslint-disable-next-line no-unused-vars */
        return new Promise((resolve, reject) => {
            $.ajax(req).then(
                // SUCCESS
                doc => {
                    // work with a copy of this.content
                    this.content.status = doc.status;
                    this.content.popup = null;

                    if (doc.ping) {
                        debug("openxpki/route - sendAjax response: \"ping\" " + doc.ping);
                        if (this.content.ping) { cancel(this.content.ping) }
                        this.doPing(doc.ping);
                    }
                    if (doc.refresh) {
                        debug("openxpki/route - sendAjax response: \"refresh\" " + doc.refresh.href + ", " + doc.refresh.timeout);
                        this.content.refresh = later(this, function() {
                            this.sendAjax({ page: doc.refresh.href });
                        }, doc.refresh.timeout);
                    }
                    if (doc.goto) {
                        debug("openxpki/route - sendAjax response: \"goto\" " + doc.goto);
                        if (doc.target === '_blank' || /^(http|\/)/.test(doc.goto)) {
                            window.location.href = doc.goto;
                        }
                        else {
                            this.transitionTo("openxpki", doc.goto);
                        }
                    }
                    else if (doc.structure) {
                        debug("openxpki/route - sendAjax response: \"structure\"");
                        this.content.navEntries = doc.structure; this.updateNavEntryActiveState();
                        this.content.user = doc.user;
                        this.content.rtoken = doc.rtoken;

                        // set locale
                        if (doc.language) {
                            this.oxiLocale.locale = doc.language;
                        }
                    }
                    else {
                        if (doc.page && doc.main) {
                            debug("openxpki/route - sendAjax response: \"page\" and \"main\"");
                            this.content.tabs = [...this.content.tabs]; // copy tabs to not trigger change observers for now
                            let newTab = {
                                active: true,
                                page: doc.page,
                                main: doc.main,
                                right: doc.right
                            };

                            // Mark the first form on screen: only the first one is allowed to focus
                            // its first input field.
                            let isFirst = true;
                            for (const section of [...(newTab.main||[]), ...(newTab.right||[])]) {
                                if (section.type === "form") {
                                    section.content.isFirstForm = isFirst;
                                    if (isFirst) isFirst = false;
                                }
                            }

                            if (targetElement === "popup") {
                                this.content.popup = newTab;
                            }
                            else if (targetElement === "tab") {
                                let tabs = this.content.tabs;
                                tabs.setEach("active", false);
                                tabs.pushObject(newTab);
                            }
                            else if (targetElement === "active") {
                                let tabs = this.content.tabs;
                                let index = tabs.indexOf(tabs.findBy("active"));
                                tabs.replace(index, 1, [newTab]); // top
                            }
                            else {
                                this.content.tabs = [newTab];
                            }
                        }
                        this.setLoadingState(false);
                    }
                    return resolve(doc);
                },
                // FAILURE
                () => {
                    this.setLoadingState(false);
                    this.content.error = {
                        message: this.intl.t('error_popup.message')
                    };
                    return resolve({});
                }
            );
        });
    }

    updateNavEntryActiveState() {
        let page = this.content.page;
        for (const entry of this.content.navEntries) {
            emSet(entry, "active", (entry.key === page));
            if (entry.entries) {
                entry.entries.setEach("active", false);
                let subEntry = entry.entries.findBy("key", page);
                if (subEntry) {
                    emSet(subEntry, "active", true);
                    emSet(entry, "active", true);
                }
            }
        }
        this.content.navEntries = this.content.navEntries; // trigger updates
    }
}