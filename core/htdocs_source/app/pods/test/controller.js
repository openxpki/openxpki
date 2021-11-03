import Controller from '@ember/controller';
import { action } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { inject } from '@ember/service';
import Pretender from 'pretender';
import section_grid from './section-grid';
import section_keyvalue from './section-keyvalue';
import section_tiles from './section-tiles';

export default class TestController extends Controller {
    @inject('oxi-locale') oxiLocale;

    constructor() {
        super(...arguments);
        this.oxiLocale.locale = 'de-DE';

        /*
         * set up request interceptor / server mockup
         */
        const server = new Pretender(function() {
            // simulate localconfig.yaml
            this.get('/openxpki/localconfig.yaml', request => [
                    200,
                    { "Content-type": "application/yaml" },
                    'header: |-' + "\n" +
                    '    <h3>' + "\n" +
                    '        <a href="./#/"><img src="img/logo.png" class="toplogo"></a>' + "\n" +
                    '        &nbsp;' + "\n" +
                    '        <small>Test page</small>' + "\n" +
                    '    </h3>' + "\n" +
                    'accessibility:' + "\n" +
                    '    tooltipOnFocus: on' + "\n"
            ]);
            let emptyResponse = () => new Promise(resolve => {
                let response = [
                    200,
                    {'content-type': 'application/javascript'},
                    '{}'
                ];
                resolve(response);
            });

            /* ************************
             * GET requests
             */
            this.get('/openxpki/cgi-bin/webui.fcgi', req => {
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
            });

            /*
             * Autofill
             */
            this.get('/autofill', req => {
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
                console.info(`MOCKUP SERVER> POST request: ${req.url}`);
                console.debug(req);
                let params;
                if (req.requestHeaders['content-type'].match(/^application\/x-www-form-urlencoded/)) {
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

    _testButton = {
        label: "Button",
        format: "primary",
        tooltip: "This should do it",
        disabled: false,
    };

    forms = [
        {
            type: "form",
            action: "login!text",
            reset: "login!text",
            content: {
                label: "oxi-section/form #0",
                title: "Text",
                fields: [
                    {
                        type: "text",
                        name: "text",
                        label: "Text",
                        value: "",
                    },
                    {
                        type: "text",
                        name: "comment",
                        label: "Comment (will be used in autocomplete below)",
                        value: "rain",
                    },
                    {
                        type: "encrypted",
                        name: "enc_param",
                        value: "fake_jwt_token",
                    },
                    {
                        type: "text",
                        name: "text_autocomplete",
                        label: "Autocomplete",
                        value: "pre",
                        tooltip: "Simulated autocomplete: Enter anything to get three results, or 'boom' to simulate server-side error, or 'void' for empty result list.",
                        autocomplete_query: {
                            action: "text!autocomplete",
                            params: {
                                the_comment: "comment",
                                secure_param: "enc_param",
                            },
                        },
                    },
                    {
                        type: "textarea",
                        name: "text_autofill",
                        label: "Autofill",
                        autofill: {
                            request: {
                                url: `${window.location.protocol}//${window.location.host}/autofill`,
                                method: 'GET',
                                params: {
                                    user: { the_comment: "comment" },
                                    static: { forest: "deep" },
                                },
                            },
                            autorun: true,
                            label: "The Oracle",
                            button_label: "Per Smartcard erzeugen",
                        },
                    },
                ],
            }
        },

        {
            type: "form",
            action: "login!password",
            reset: "login!password",
            content: {
                label: "oxi-section/form #1",
                title: "Bool + Select",
                fields: [
                    {
                        type: "bool",
                        name: "ready_or_not",
                        label: "Bool, selected",
                        value: 1,
                    },
                    {
                        type: "select",
                        name: "select_it",
                        label: "Select, no preset",
                        options: [
                            { value: 1, label: "Major" },
                            { value: 2, label: "Tom" },
                        ],
                    },
                    {
                        type: "select",
                        name: "select_editable",
                        label: "Select, editable",
                        editable: 1,
                        value: 2,
                        options: [
                            { value: 1, label: "Tusen" },
                            { value: 2, label: "Takk" },
                        ],
                    },
                    {
                        type: "select",
                        name: "select_2",
                        label: "Select, one choice",
                        options: [
                            { value: "11", label: "Ocean" },
                        ],
                        value: "",
                    },
                ],
                buttons: [
                    {
                        label: "Link to external",
                        format: "failure",
                        tooltip: "Just fyi",
                        href: "https://www.openxpki.org",
                        target: "_blank",
                    },
                    this._testButton,
                    {
                        ...this._testButton,
                        label: "With confirmation",
                        confirm: {
                            label: "Really sure?",
                            description: "Think about it one more time.",
                        },
                        break_before: 1,
                    },
                    {
                        ...this._testButton,
                        label: "Disabled",
                        disabled: true,
                    },
                ],
            }
        },

        {
            type: "form",
            action: "login!password",
            reset: "login!password",
            content: {
                label: "oxi-section/form #2",
                title: "Password",
                fields: [
                    {
                        type: "password",
                        name: "pwd",
                        label: "Password",
                        tooltip: "Please choose wisely",
                    },
                    {
                        type: "passwordverify",
                        name: "pwd_verified",
                        label: "Password, verifiable",
                    },
                    {
                        type: "passwordverify",
                        name: "pwd_verified_preset",
                        label: "Password, verifiable, preset",
                        value: "123\n",
                    },
                ],
            }
        },

        {
            type: "form",
            action: "login!password",
            reset: "login!password",
            content: {
                label: "oxi-section/form #3",
                title: "Datetime",
                fields: [
                    {
                        type: "datetime",
                        name: "dt_now",
                        label: "Date, now",
                        placeholder: "Please select a date...",
                    },
                    {
                        type: "datetime",
                        name: "dt_now_preset",
                        label: "Date, now (preset)",
                        timezone: "local",
                        value: "now",
                    },
                    {
                        type: "datetime",
                        name: "dt_some_local",
                        label: "Date, 2020-03-03 03:33 UTC\nepoch = 1583206380",
                        timezone: "local",
                        value: "1583206380",
                    },
                    {
                        type: "datetime",
                        name: "dt_some",
                        label: "Date, 2020-03-03 03:33 UTC",
                        value: "1583206380",
                    },
                    {
                        type: "datetime",
                        name: "dt_some_pitcairn",
                        label: "Date, 2020-03-03 03:33 UTC",
                        value: "1583206380",
                        timezone: "Pacific/Pitcairn",
                    },
                ],
            }
        },

        {
            type: "form",
            action: "login!password",
            reset: "login!password",
            content: {
                label: "oxi-section/form #4",
                title: "Cloneable fields",
                fields: [
                    {
                        type: "text",
                        name: "plaintext",
                        label: "Text, cloneable, 2 presets",
                        value: ["sheep #1", "sheep #2"],
                        clonable: 1,
                    },
                    {
                        type: "text",
                        name: "attributes",
                        label: "Text, dynamic, clonable, 2 presets",
                        clonable: 1,
                        is_optional: 1,
                        keys: [
                            {
                                value: "cert_subject",
                                label: "Certificate Subject",
                            },
                            {
                                value: "requestor",
                                label: "Requestor",
                            },
                            {
                                value: "transaction_id",
                                label: "Transaction Id",
                            },
                        ],
                        value: [
                            { key: "cert_subject", value: "Subject" },
                            { key: "transaction_id", value: "TransId" },
                        ],
                    },
                ],
            }
        },

        {
            type: "form",
            action: "login!password",
            reset: "login!password",
            content: {
                label: "oxi-section/form #5",
                title: "Various",
                fields: [
                    {
                        type: "rawtext",
                        name: "rawtext",
                        label: "Raw text",
                        value: "",
                    },
                    {
                        type: "static",
                        name: "label1",
                        label: "Static",
                        value: "on my shirt",
                    },
                    {
                        type: "static",
                        name: "label2",
                        label: "Static",
                        value: "on my shirt",
                        verbose: "is sewed onto my shirt"
                    },
                    {
                        type: "textarea",
                        name: "prosa",
                        label: "Textarea",
                        value: "Hi there!\nHow are you?\n",
                    },
                    {
                        type: "textarea",
                        name: "prosa_autofill",
                        label: "Textarea (Autofill)",
                        value: "",
                        autofill: {
                            request: {
                                url: `${window.location.protocol}//${window.location.host}/autofill`,
                                method: 'GET',
                                params: {
                                    static: { this: "it" },
                                },
                            },
                            label: "The Oracle",
                            button_label: "Per Smartcard erzeugen",
                        },
                    },
                    {
                        type: "textarea",
                        name: "textarea_upload",
                        value: "...data...",
                        label: "Textarea (Autofill + Upload)",
                        allow_upload: 1,
                        autofill: {
                            request: {
                                url: `${window.location.protocol}//${window.location.host}/autofill`,
                                method: 'GET',
                                params: {
                                    user: { text: "rawtext" },
                                    static: { forest: "deep" },
                                },
                            },
                            autorun: 1,
                            label: "The Oracle",
                        },
                    },
                ],
            }
        },

        {
            type: "form",
            action: "login!password",
            reset: "login!password",
            content: {
                label: "oxi-section/form #6",
                title: "Tooltips",
                fields: [
                    {
                        type: "rawtext",
                        name: "rawtext #1",
                        label: "Raw text",
                        value: "",
                        tooltip: "Hidden message found."
                    },
                    {
                        type: "rawtext",
                        name: "rawtext #2",
                        label: "Raw text",
                        value: "",
                        tooltip: "Use sushi in fish bowl in sink."
                    },
                    {
                        type: "textarea",
                        name: "prosa",
                        label: "Textarea",
                        value: "Hi there!\nHow are you?\n",
                        tooltip: "You should give the peanuts to the two-headed squirrel."
                    },
                ],
            }
        },
    ];

    @tracked
    sections = [
        section_grid,
        section_keyvalue,
        section_tiles,
    ];

    chartDef1 = {
        type: 'chart',
        className: 'test-chart',
        content: {
            options: {
                type: 'line',
                title: 'Line',
                width: 250,
                height: 150,
                x_is_timestamp: true,
                legend_label: true,
                legend_value: true,
                series: [
                    {
                        label: 'Certs',
                        color: 'rgba(0, 100, 200, 1)',
                    },
                    {
                        label: 'Usage',
                        scale: '%',
                        color: 'rgba(200, 30, 100, 1)',
                        line_width: 2,
                    },
                ],
            },
            data: [[1609462800,'290','53.6'],[1609549260,'289','51.3'],[1609635720,'287','51.8'],[1609722180,'275','52.7'],[1609808640,'270','53.4'],[1609895100,'262','56.0'],[1609981560,'268','56.0'],[1610068020,'273','57.0'],[1610154480,'260','56.1'],[1610240940,'271','57.6'],[1610327400,'281','58.3'],[1610413860,'291','60.4'],[1610500320,'292','61.0'],[1610586780,'292','62.5'],[1610673240,'292','63.0'],[1610759700,'293','66.0'],[1610846160,'293','65.9'],[1610932620,'293','65.1'],[1611019080,'293','63.8'],[1611105540,'293','64.1'],[1611192000,'292','61.1'],[1611278460,'293','63.5'],[1611364920,'293','62.5'],[1611451380,'292','60.7'],[1611537840,'293','61.3'],[1611624300,'293','60.8'],[1611710760,'293','61.1'],[1611797220,'293','60.8'],[1611883680,'293','60.8'],[1611970140,'293','62.3'],[1612056600,'293','63.7'],[1612143060,'294','65.2'],[1612229520,'293','61.4'],[1612315980,'294','62.5'],[1612402440,'293','60.3'],[1612488900,'293','60.1'],[1612575360,'293','61.0'],[1612661820,'294','61.6'],[1612748280,'294','62.5'],[1612834740,'294','63.5'],[1612921200,'294','60.7'],[1613007660,'293','59.8'],[1613094120,'293','59.7'],[1613180580,'293','58.3'],[1613267040,'293','58.9'],[1613353500,'293','57.3'],[1613439960,'293','57.4'],[1613526420,'293','58.8'],[1613612880,'293','58.5'],[1613699340,'293','57.8'],[1613785800,'293','58.4'],[1613872260,'293','58.1'],[1613958720,'293','57.3'],[1614045180,'293','57.1'],[1614131640,'293','57.8'],[1614218100,'293','58.0'],[1614304560,'293','57.9'],[1614391020,'294','58.6'],[1614477480,'294','59.7'],[1614563940,'294','58.4'],[1614650400,'294','59.1'],[1614736860,'294','60.0'],[1614823320,'294','60.1'],[1614909780,'294','57.7'],[1614996240,'293','57.1'],[1615082700,'293','56.9'],[1615169160,'293','56.8'],[1615255620,'293','55.9'],[1615342080,'293','56.3'],[1615428540,'293','56.2'],[1615515000,'293','56.6'],[1615601460,'293','56.7'],[1615687920,'293','55.6'],[1615774380,'293','55.7'],[1615860840,'293','52.7'],[1615947300,'292','51.4'],[1616033760,'292','52.3'],[1616120220,'293','52.6'],[1616206680,'293','52.8'],[1616293140,'293','53.7'],[1616379600,'293','53.4'],[1616466060,'293','53.4'],[1616552520,'293','53.6'],[1616638980,'293','54.3'],[1616725440,'293','54.7'],[1616811900,'293','55.1'],[1616898360,'293','53.2'],[1616984820,'293','54.0'],[1617071280,'293','52.9'],[1617157740,'292','51.3'],[1617244200,'292','51.7'],[1617330660,'292','48.7'],[1617417120,'292','49.6'],[1617503580,'292','48.8'],[1617590040,'292','49.2'],[1617676500,'292','49.9'],[1617762960,'292','48.7'],[1617849420,'292','50.2'],[1617935880,'292','50.3']],
        },
    };

    chartDef2 = {
        type: 'chart',
        className: 'test-chart',
        content: {
            options: {
                type: 'bar',
                title: 'Bar',
                width: 250,
                height: 150,
                series: [
                    {
                        label: 'Requested',
                        color: 'rgba(0, 100, 200, 0.9)',
                        scale: '%',
                    },
                    {
                        label: 'Renewed',
                        color: 'rgba(200, 200, 200, 1)',
                        scale: '%',
                    },
                    {
                        label: 'Revoked',
                        color: 'rgba(200, 30, 100, 0.9)',
                        scale: '%',
                    },
                ],
            },
            data: [['2018','23.8','53.6','37.4'],['2019','19.6','43.3','63.4'],['2020','4.2','51.8','47.4']],
        }
    };

    chartDef3 = {
        type: 'chart',
        className: 'test-chart',
        content: {
            options: {
                type: 'bar',
                title: 'Bar: one group',
                width: 250,
                height: 150,
                series: [
                    {
                        label: 'Requested',
                    },
                    {
                        label: 'Renewed',
                    },
                    {
                        label: 'Revoked',
                    },
                ],
            },
            data: [['2019','23.8','53.6','37.4']],
        }
    };

    chartDef4 = {
        type: 'chart',
        className: 'test-chart',
        content: {
            options: {
                type: 'pie',
                title: 'Pie',
                width: 250,
                height: 150,
                series: [
                    {
                        label: 'Requested',
                    },
                    {
                        label: 'Renewed',
                    },
                    {
                        label: 'Revoked',
                    },
                    {
                        label: 'Unchanged',
                    },
                ],
            },
            data: [['2019','14','44','30','12']],
        }
    };
}
