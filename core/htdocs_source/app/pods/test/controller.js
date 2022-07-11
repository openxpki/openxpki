import Controller from '@ember/controller';
import { action } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';
import Pretender from 'pretender';
import section_chart from './section-chart';
import section_form from './section-form';
import section_grid from './section-grid';
import section_keyvalue from './section-keyvalue';
import section_tiles from './section-tiles';

export default class TestController extends Controller {
    @service('oxi-locale') oxiLocale;

    constructor() {
        super(...arguments);
        this.oxiLocale.locale = 'de-DE';

        /*
         * set up request interceptor / server mockup
         */
        const server = new Pretender(function() {
            // simulate localconfig.yaml
            this.get('/openxpki/localconfig.yaml', request => [ // eslint-disable-line ember/classic-decorator-no-classic-methods
                    200,
                    { "Content-type": "application/yaml" },
                    'header: |-' + "\n" +
                    '    <h3>' + "\n" +
                    '        <a href="./#/"><img src="img/logo.png" class="toplogo"></a>' + "\n" +
                    '        &nbsp;' + "\n" +
                    '        <small>Test page</small>' + "\n" +
                    '    </h3>' + "\n"
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
            this.get('/openxpki/cgi-bin/webui.fcgi', req => { // eslint-disable-line ember/classic-decorator-no-classic-methods
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
            this.get('/autofill', req => { // eslint-disable-line ember/classic-decorator-no-classic-methods
                console.info(`MOCKUP SERVER> autofill request`);
                console.info(Object.entries(req.queryParams).map(e => `MOCKUP SERVER> ${e[0]} = ${e[1]}`).join("\n"));
                console.debug(req);
                let result = req.queryParams;
                return [200, {"Content-Type": "application/json"}, JSON.stringify(result)];
            });

            /* ************************
             * POST requests
             */
            this.post('/openxpki/cgi-bin/webui.fcgi', req => {
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
        });
        server.unhandledRequest = function(verb, path, req) {
            console.info("AJAX REQUEST", verb, path, req);
        }
        // server.handledRequest = function(verb, path, req) {}
    }

    @action
    setLang(lang) {
        this.oxiLocale.locale = lang;
    }

    @action
    setCurrentForm(index) {
        this.selectedFormIndex = index;
    }

    @tracked
    selectedFormIndex = 0;

    charts = section_chart;

    forms = section_form;

    sections = [
        section_grid,
        section_keyvalue,
        section_tiles,
    ];

}
