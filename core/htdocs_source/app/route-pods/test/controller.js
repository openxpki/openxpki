import Controller from '@ember/controller'
import { action } from "@ember/object"
import { tracked } from '@glimmer/tracking'
import { service } from '@ember/service'
import Pretender from 'pretender'
import section_chart from './section-chart'
import section_form from './section-form'
import section_grid from './section-grid'
import section_keyvalue from './section-keyvalue'
import section_tiles from './section-tiles'
import section_cards from './section-cards'
import section_cards_vertical from './section-cards-vertical'
import TestButtons from './buttons'
import ContainerButton from 'openxpki/data/container-button'
import ENV from 'openxpki/config/environment'

export default class TestController extends Controller {
    @service('oxi-locale') oxiLocale;

    @tracked
    selectedFormIndex = 0

    buttons = []

    charts = section_chart
    forms = section_form
    sections = [
        section_grid,
        section_keyvalue,
        section_tiles,
        section_cards,
        section_cards_vertical,
    ]
    test_buttons = TestButtons

    localconfig = `
header:
    logo: img/logo.png
    title: Test page
`

    localRequestPath = 'test-server'
    localRequestUrl = 'http://localhost:7780/' + this.localRequestPath

    get formNavButtons() {
        let buttons = []
        this.forms.forEach((form, i) => {
            buttons.push(ContainerButton.fromHash({
                format: "optional",
                label: form.content.title,
                onClick: async btn => this.setCurrentForm(i),
            }))
        })
        return buttons
    }

    #toUrlParams(entries) {
        let result = [];
        let URLPARAM_FIND = /[!'()~]|%20/g;
        let URLPARAM_REPLACE = { '!': '%21', "'": '%27', '(': '%28', ')': '%29', '~': '%7E', '%20': '+' };
        let serialize = v => encodeURIComponent(v ?? '').replace(URLPARAM_FIND, match => URLPARAM_REPLACE[match]);

        Object.keys(entries).forEach(k => result.push(serialize(k) + '=' + serialize(entries[k])));
        return result.join('&');
    }

    async localRequest() {
        console.log('Sending request to localhost...');

        let data = {
            colour : 'blue',
            time : new Date().getTime(),
        };

        let url = this.localRequestUrl + '?' + this.#toUrlParams(data);

        let fetchParams = {
            method : 'GET',
            headers : {
                'Content-Type' : 'application/x-www-form-urlencoded; charset=UTF-8'
            },
        }

        return fetch(url, fetchParams)
        .then(response => {
            console.log('Response from local server:', response)
            if (response.ok) {
                return response.json();
            }
            // Handle non-2xx HTTP status codes
            else {
                console.error(response.status);
            }
        })
        .then(doc => {
            console.log('Decoded JSON: ', doc);
        })
    }

    constructor() {
        super(...arguments);
        this.oxiLocale.locale = 'de-DE';
        this.buttons = [
            ContainerButton.fromHash({
                format: "expected",
                label: "de-DE",
                onClick: async btn => this.setLang("de-DE"),
            }),
            ContainerButton.fromHash({
                format: "expected",
                label: "en-US",
                onClick: async btn => this.setLang("en-US"),
            }),
            ContainerButton.fromHash({
                format: "expected",
                label: 'Local request - ' + this.localRequestUrl,
                tooltip: "morbo -l http://*:7780 ./test-server.pl",
                onClick: async btn => this.localRequest(),
            }),
        ]

        /*
         * set up request interceptor / server mockup
         */
        const server = new Pretender();

        // simulate localconfig.yaml
        server.get(`${ENV.rootURL}localconfig.yaml`, request => [ // eslint-disable-line ember/classic-decorator-no-classic-methods
                200, { "Content-type": "application/yaml" }, this.localconfig
        ]);
        let emptyResponse = () => new Promise(resolve => {
            let response = [
                200,
                {'Content-Type': 'application/javascript'},
                '{}'
            ];
            resolve(response);
        });

        /* ************************
         * GET requests
         */
        server.get(`${ENV.rootURL}cgi-bin/webui.fcgi`, req => { // eslint-disable-line ember/classic-decorator-no-classic-methods
            console.info(`MOCKUP SERVER> GET request: ${req.url}`);
            console.info(Object.entries(req.queryParams).map(e => `MOCKUP SERVER> ${e[0]} = ${e[1]}`).join("\n"));
            console.debug(req);

            /*
             * dynamic tooltip - text
             */
            if (req.queryParams?.page == 'tooltip!user!123') {
                let result = {
                    type: "text",
                    content: {
                        description: "Fred&nbsp;<b>Flintstone</b>",
                    },
                };

                return [200, {"Content-Type": "application/json"}, JSON.stringify(result)];
            }

            /*
             * dynamic tooltip - chart
             */
            if (req.queryParams?.page == 'tooltip!chart') {
                let result = {
                    type: 'chart',
                    className: 'test-chart',
                    content: {
                        options: {
                            type: 'pie',
                            title: 'Pie',
                            width: 300, height: 150,
                            series: [ { label: 'Requested' }, { label: 'Renewed' }, { label: 'Revoked' } ],
                        },
                        data: [['2019','14','44','30']],
                    }
                };

                return [200, {"Content-Type": "application/json"}, JSON.stringify(result)];
            }

            return emptyResponse();
        }, 1000);

        /*
         * Autofill
         */
        server.get('/autofill', req => { // eslint-disable-line ember/classic-decorator-no-classic-methods
            console.info(`MOCKUP SERVER> autofill request`);
            console.info(Object.entries(req.queryParams).map(e => `MOCKUP SERVER> ${e[0]} = ${e[1]}`).join("\n"));
            console.debug(req);
            let result = req.queryParams;
            return [200, {"Content-Type": "application/json"}, JSON.stringify(result)];
        });

        /* ************************
         * POST requests
         */
        server.post(`${ENV.rootURL}cgi-bin/webui.fcgi`, req => {
            let headers = req.requestHeaders
            let contentType = headers[Object.keys(headers).find(el => el.toLowerCase() == 'content-type')]
            console.info(`MOCKUP SERVER> POST request: ${req.url}`);
            console.debug(req);
            let params;
            if (contentType.match(/^application\/x-www-form-urlencoded/)) {
                params = decodeURIComponent(req.requestBody.replace(/\+/g, ' ')).split('&').join("\n");
            }
            else {
                params = JSON.parse(req.requestBody);
            }
            console.info('MOCKUP SERVER> parameters:', params);

            /*
             * autocomplete
             */
            if (params?.action == 'text!autocomplete') {
                let val = params.text_autocomplete;
                let forest = params.forest || '(not provided)';
                let comment = params.the_comment || '(not provided)';

                if (params._encrypted_jwt_secure_param != 'fake_jwt_token')
                  throw new Error('Encrypted JWT token was not sent');

                console.info(`MOCKUP SERVER> autocomplete - value: ${val}, forest: ${forest}, the_comment: ${comment}`);

                let result;
                if ('boom' === val) {
                    result = { error: 'There is no spoon.' };
                }
                else if ('void' === val) {
                    result = [];
                }
                else {
                    result = [
                        { label : `Bag - ${comment}`, value : `${val}-123` },
                        { label : `Box - ${comment}`, value : `${val}-567` },
                        { label : `Bucket - ${comment}`, value : `${val}-890` },
                    ];
                }
                return [200, {"Content-Type": "application/json"}, JSON.stringify(result)];
            }

            return emptyResponse();
        });

        server.unhandledRequest = (verb, path, req) => {
            // pass through a request to a locally running server
            if (path.includes(this.localRequestPath)) {
                console.debug("MOCKUP SERVER> Passing through request to backend")
                return req.passthrough()
            }

            // otherwise show request
            console.info("MOCKUP SERVER> Unhandled request", verb, path, req)
        }

        server.handledRequest = function(verb, path, req) {};
    }

    @action
    setLang(lang) {
        this.oxiLocale.locale = lang;
    }

    async setCurrentForm(index) {
        this.selectedFormIndex = index;
    }
}
