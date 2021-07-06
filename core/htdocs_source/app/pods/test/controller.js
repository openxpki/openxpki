import Controller from '@ember/controller';
import { action } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { inject } from '@ember/service';
import Pretender from 'pretender';

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
                    '    <h2>' + "\n" +
                    '        <a href="./#/"><img src="img/logo.png" class="toplogo"></a>' + "\n" +
                    '        &nbsp;' + "\n" +
                    '        <small>Test page</small>' + "\n" +
                    '    </h2>' + "\n" +
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

            this.post('/openxpki/cgi-bin/webui.fcgi', req => {
                console.info(`MOCKUP SERVER> POST request: ${req.url}`);
                let params;
                if (req.requestHeaders['content-type'].match(/^application\/x-www-form-urlencoded/)) {
                    params = decodeURIComponent(req.requestBody.replace(/\+/g, ' ')).split('&').join("\n");
                }
                else {
                    params = JSON.parse(req.requestBody);
                }
                console.info(params);
                console.debug(req);

                /*
                 * autocomplete
                 */
                if (params?.action == 'text!autocomplete') {
                    let val = params.value;
                    let forest = params.params.forest;
                    let comment = params.form_params.comment || '(not provided)';

                    console.info(`MOCKUP SERVER> autocomplete - value: ${val}, forest: ${forest}, comment: ${comment}`);

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

    additionalGridRows() {
        let result = [];
        // add some more grid rows
        for (let i=0; i<50; i++) {
            result.push([
                334455 + i,
                `CN=client-${i},DC=Test Deployment,DC=OpenXPKI,DC=org`,
                {
                    value: "ISSUED",
                    label: "Issued"
                },
                1585959633 + 60*60*24*i,
                `${1585959633 + 60*60*24*i}`,
                `ID-IS-${i}`,
                `id-${i}`,
                {
                    label: "Issued",
                    value: "ISSUED"
                }
            ]);
        }
        return result;
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
                        type: "text",
                        name: "text_autocomplete",
                        label: "Autocomplete",
                        value: "pre",
                        tooltip: "Simulated autocomplete: Enter anything to get three results, or 'boom' to simulate server-side error, or 'void' for empty result list.",
                        autocomplete: {
                            action: "text!autocomplete",
                            params: {
                                forest: "shallow",
                            },
                        },
                    },
                    {
                        type: "text",
                        name: "text_autocomplete_ref",
                        label: "Autocomplete (using field 'comment')",
                        tooltip: "Simulated autocomplete: Enter anything to get three results, or 'boom' to simulate server-side error, or 'void' for empty result list.",
                        autocomplete: {
                            action: "text!autocomplete",
                            params: {
                                forest: "deep",
                            },
                            form_params: [ "comment" ],
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
                        type: "uploadarea",
                        name: "uploadarea",
                        value: "...data...",
                        label: "Uploadarea",
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
        {
            type: "grid",
            className: "certificate",
            content: {
                label: "oxi-section/grid",
                empty: "No data available",
                buttons: [
                    {
                        section: "Some",
                    },
                    {
                        format: "expected",
                        page: "certificate!search!query!rJdrIbg1P6xsE6b9RtQCXp291SE",
                        label: "Reload Search Form",
                        description: "Button 1",
                    },
                    {
                        format: "alternative",
                        page: "redirect!certificate!result!id!rJdrIbg1P6xsE6b9RtQCXp291SE",
                        label: "Refresh Result",
                        description: "Button 2",
                    },
                    {
                        section: "Others",
                    },
                    {
                        label: "New Search",
                        format: "failure",
                        page: "certificate!search"
                    },
                    {
                        label: "Export Result",
                        format: "optional",
                        target: "_blank",
                        href: "/cgi-bin/webui.fcgi?page=certificate!export!id!rJdrIbg1P6xsE6b9RtQCXp291SE"
                    }
                ],
                actions: [
                    {
                        label: "Download",
                        icon: "download",
                        path: "certificate!detail!identifier!{identifier}",
                        target: "popup"
                    },
                    {
                        label: "Check",
                        icon: "download",
                        path: "certificate!detail!identifier!{identifier}",
                        target: "popup"
                    }
                ],
                columns: [
                    {
                        sTitle: "Certificate Serial",
                        sortkey: "cert_key"
                    },
                    {
                        sTitle: "Subject",
                        sortkey: "subject"
                    },
                    {
                        format: "certstatus",
                        sortkey: "status",
                        sTitle: "Status"
                    },
                    {
                        sTitle: "not before",
                        sortkey: "notbefore",
                        format: "timestamp"
                    },
                    {
                        format: "raw",
                        sortkey: "notafter",
                        sTitle: "raw"
                    },
                    {
                        sortkey: "identifier",
                        sTitle: "Certificate Identifier"
                    },
                    {
                        sTitle: "identifier",
                        bVisible: 0
                    },
                    {
                        sTitle: "_className"
                    },
                ],
                data: [
                    [
                        "0x3ff536fff8da93943aa",
                        "CN=e.d.c:pkiclient,DC=Test Deployment,DC=OpenXPKI,DC=org",
                        {
                            value: "ISSUED",
                            label: "Issued"
                        },
                        "1585959633",
                        "1617495633",
                        "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                        "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                        {
                            label: "Issued",
                            value: "ISSUED"
                        }
                    ],
                    [
                        "0x2ff8fa8ee5590e2553a",
                        "CN=sista.example.org:pkiclient,DC=Test Deployment,DC=OpenXPKI,DC=org",
                        {
                            label: "Issued",
                            value: "ISSUED"
                        },
                        "1585434533",
                        "<a href=\"test\" onclick=\"alert('huh')\">test</a>",
                        "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                        "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                        {
                            label: "Issued",
                            value: "ISSUED"
                        }
                    ],

                    ...this.additionalGridRows(),
                ]
            },
        },

        {
            type: "keyvalue",
            content: {
                label: "oxi-section/keyvalue",
                description: "",
                data: [
                    {
                        format: "certstatus",
                        label: "certstatus",
                        value: {
                            value: "issued",
                            label: "<i>Issued</i>",
                            tooltip: "It's issued",
                        },
                    },
                    {
                        format: "link",
                        label: "link",
                        value: {
                            page: "workflow!load!wf_id!13567",
                            label: 13567,
                            target: "_blank",
                        },
                    },
                    {
                        format: "extlink",
                        label: "extlink",
                        value: {
                            page: "https://www.openxpki.org",
                            label: "OpenXPKI",
                            target: "_blank",
                        },
                    },
                    {
                        format: "timestamp",
                        label: "timestamp",
                        value: 1617495633,
                    },
                    {
                        format: "text",
                        label: "text",
                        value: "Link to <a href=\"should be escaped\">OpenXPKI</a>",
                    },
                    {
                        format: "text",
                        label: "text_as_list",
                        value: [ "CN=sista.example.org:pkiclient,", "DC=Test Deployment,", "DC=PKI Examples,", "DC=OpenXPKI,", "DC=org" ],
                    },
                    {
                        format: "nl2br",
                        label: "nl2br",
                        value: "Link to <a href=\"should be escaped\">OpenXPKI</a>\nand a comment",
                    },
                    {
                        format: "code",
                        label: "code",
                        value: "console.log('Hello world');\nArray.isArray([yep:'I_am'])",
                    },
                    {
                        format: "asciidata",
                        label: "asciidata",
                        value: "-----BEGIN CERTIFICATE-----\nMIIGdTCCBF2gAwIBAgIKBf/x2/q69qfgJjANBgkqhkiG9w0BAQsFADBTMQswCQYD\nVQQGEwJERTERMA8GA1UECgwIT3BlblhQS0kxDDAKBgNVBAsMA1BLSTEjMCEGA1UE\nAwwaT3BlblhQS0kgRGVtbyBJc3N1aW5nIENBIDEwHhcNMjAwNDE1MTQzMjUyWhcN\nMjEwNDE1MTQzMjUyWjBqMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxHzAdBgoJkiaJk/IsZAEZFg9UZXN0IERlcGxveW1lbnQx\nGDAWBgNVBAMMD2EuYi5jOnBraWNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBANj1rNdqbwgOKzCE76VB6tL9oMoASVXZvmTYUGORu+NgsrdpeKiG\n1rateJkosjgcUYhSgBJzvMW/3ZjJ94s90mA9eieuHSeYyxb8CMzR/cAkTj4gYr04\nJh4Q5NWp2DU+lDGHK2VnfIdxlTQuFGu5N7BET5DfRjXIiiPjOeQhzrXoUzyU8D50\nCWVmTtQ18qLbQEOgyUgCPNCJGEglA5tGJg7vDm3LZRl8qc26ynSmUEzvq6tDreyG\n+9AsQti4qZg2FUypvI1TFjSDv+J5tyq471scPyDBYEQI/lnKo1HGH+6a0HFgUu7H\nDcOqz2kIv+kyAocS8fvUCM8c+MZWNwxh80MCAwEAAaOCAjIwggIuMIGABggrBgEF\nBQcBAQR0MHIwSgYIKwYBBQUHMAKGPmh0dHA6Ly9wa2kuZXhhbXBsZS5jb20vZG93\nbmxvYWQvT3BlblhQS0lfRGVtb19Jc3N1aW5nX0NBXzEuY2VyMCQGCCsGAQUFBzAB\nhhhodHRwOi8vb2NzcC5leGFtcGxlLmNvbS8wTQYDVR0jBEYwRIAUv47981hKI/BJ\npmcdFera3Ht0/GyhIaQfMB0xGzAZBgNVBAMMEk9wZW5YUEtJIFJvb3QgQ0EgMYIJ\nAKXvcf7VbanOMAwGA1UdEwEB/wQCMAAwTwYDVR0fBEgwRjBEoEKgQIY+aHR0cDov\nL3BraS5leGFtcGxlLmNvbS9kb3dubG9hZC9PcGVuWFBLSV9EZW1vX0lzc3Vpbmdf\nQ0FfMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwCQYDVR0SBAIwADAOBgNV\nHQ8BAf8EBAMCB4AwgagGA1UdIASBoDCBnTCBmgYDKgMEMIGSMCsGCCsGAQUFBwIB\nFh9odHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMCsGCCsGAQUFBwIBFh9o\ndHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMDYGCCsGAQUFBwICMCoaKFRo\naXMgaXMgYSBjb21tZW50IGZvciBwb2xpY3kgb2lkIDEuMi4zLjQwHQYDVR0OBBYE\nFCmEqRsgxL3M9npTB/UlYv/IBc1rMA0GCSqGSIb3DQEBCwUAA4ICAQAlRwaMKaI9\nMuM/gpu9QEiQNfAwTD9CO6fMEfcOv6yZIaNBWlw151XxDS5qysJ5ccQuo93Hhcwa\nbEnYG7v5MFMrKvg24RW3lzHo4PdMFTeKcnKbXPIprvtWlOEqwoezdNJBP9bdSGcS\nxUSuLBPYWKt73qmc1+n8dpJp2E3FijMSPoSDV+B52Tu2d7KjYnuRtbxhAEY6Lz+2\n9BZYf+k+FGrerGyV/rpQ/IoUqQsJbffUOld0ffi+BAegIx4Ml+hPBpxu+XR1xyE7\n5Y5lzSs0NBDB7wslcG6jNGTsse3k2WumOrmbdAX5ExoYg+HAReFywJiLOzC4vqup\nRE2H1hSY3jcPJOalIk/WIzFrLJ8DbaLR4GFaABQ9WkWD9GlWZIURdmB8A+0ufoW/\nEh4YgOSI0z15QrwboZrb403A8/rZ3LTDyQmbz4iM+LJIJ+c9QG+k1AHuWLUbeoc5\n/GbNTRRb5SQXaikbOnQG+U4vX8WZxnMl6lTYa9RykzUaemFRbq8Zm4bbWdFuSWHS\n9F/K+0i806MzOITE+W2EbY5Flx5riAarTr5utOrYL041SQz5qDfxoCSlRnC9PRGH\ny8eRk4foj31XcTWNz6IBe4mNUpun6Gker6o8ahEvhbRM7FLCzqLC2zXldT+KCYUv\nYHhZ+3jIWNoPuYa6gqgJbF0WTcNS2bttEw==\n-----END CERTIFICATE-----",
                    },
                    {
                        format: "download",
                        label: "download",
                        value: {
                            data: "-----BEGIN CERTIFICATE-----\nMIIGdTCCBF2gAwIBAgIKBf/x2/q69qfgJjANBgkqhkiG9w0BAQsFADBTMQswCQYD\nVQQGEwJERTERMA8GA1UECgwIT3BlblhQS0kxDDAKBgNVBAsMA1BLSTEjMCEGA1UE\nAwwaT3BlblhQS0kgRGVtbyBJc3N1aW5nIENBIDEwHhcNMjAwNDE1MTQzMjUyWhcN\nMjEwNDE1MTQzMjUyWjBqMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxHzAdBgoJkiaJk/IsZAEZFg9UZXN0IERlcGxveW1lbnQx\nGDAWBgNVBAMMD2EuYi5jOnBraWNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBANj1rNdqbwgOKzCE76VB6tL9oMoASVXZvmTYUGORu+NgsrdpeKiG\n1rateJkosjgcUYhSgBJzvMW/3ZjJ94s90mA9eieuHSeYyxb8CMzR/cAkTj4gYr04\nJh4Q5NWp2DU+lDGHK2VnfIdxlTQuFGu5N7BET5DfRjXIiiPjOeQhzrXoUzyU8D50\nCWVmTtQ18qLbQEOgyUgCPNCJGEglA5tGJg7vDm3LZRl8qc26ynSmUEzvq6tDreyG\n+9AsQti4qZg2FUypvI1TFjSDv+J5tyq471scPyDBYEQI/lnKo1HGH+6a0HFgUu7H\nDcOqz2kIv+kyAocS8fvUCM8c+MZWNwxh80MCAwEAAaOCAjIwggIuMIGABggrBgEF\nBQcBAQR0MHIwSgYIKwYBBQUHMAKGPmh0dHA6Ly9wa2kuZXhhbXBsZS5jb20vZG93\nbmxvYWQvT3BlblhQS0lfRGVtb19Jc3N1aW5nX0NBXzEuY2VyMCQGCCsGAQUFBzAB\nhhhodHRwOi8vb2NzcC5leGFtcGxlLmNvbS8wTQYDVR0jBEYwRIAUv47981hKI/BJ\npmcdFera3Ht0/GyhIaQfMB0xGzAZBgNVBAMMEk9wZW5YUEtJIFJvb3QgQ0EgMYIJ\nAKXvcf7VbanOMAwGA1UdEwEB/wQCMAAwTwYDVR0fBEgwRjBEoEKgQIY+aHR0cDov\nL3BraS5leGFtcGxlLmNvbS9kb3dubG9hZC9PcGVuWFBLSV9EZW1vX0lzc3Vpbmdf\nQ0FfMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwCQYDVR0SBAIwADAOBgNV\nHQ8BAf8EBAMCB4AwgagGA1UdIASBoDCBnTCBmgYDKgMEMIGSMCsGCCsGAQUFBwIB\nFh9odHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMCsGCCsGAQUFBwIBFh9o\ndHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMDYGCCsGAQUFBwICMCoaKFRo\naXMgaXMgYSBjb21tZW50IGZvciBwb2xpY3kgb2lkIDEuMi4zLjQwHQYDVR0OBBYE\nFCmEqRsgxL3M9npTB/UlYv/IBc1rMA0GCSqGSIb3DQEBCwUAA4ICAQAlRwaMKaI9\nMuM/gpu9QEiQNfAwTD9CO6fMEfcOv6yZIaNBWlw151XxDS5qysJ5ccQuo93Hhcwa\nbEnYG7v5MFMrKvg24RW3lzHo4PdMFTeKcnKbXPIprvtWlOEqwoezdNJBP9bdSGcS\nxUSuLBPYWKt73qmc1+n8dpJp2E3FijMSPoSDV+B52Tu2d7KjYnuRtbxhAEY6Lz+2\n9BZYf+k+FGrerGyV/rpQ/IoUqQsJbffUOld0ffi+BAegIx4Ml+hPBpxu+XR1xyE7\n5Y5lzSs0NBDB7wslcG6jNGTsse3k2WumOrmbdAX5ExoYg+HAReFywJiLOzC4vqup\nRE2H1hSY3jcPJOalIk/WIzFrLJ8DbaLR4GFaABQ9WkWD9GlWZIURdmB8A+0ufoW/\nEh4YgOSI0z15QrwboZrb403A8/rZ3LTDyQmbz4iM+LJIJ+c9QG+k1AHuWLUbeoc5\n/GbNTRRb5SQXaikbOnQG+U4vX8WZxnMl6lTYa9RykzUaemFRbq8Zm4bbWdFuSWHS\n9F/K+0i806MzOITE+W2EbY5Flx5riAarTr5utOrYL041SQz5qDfxoCSlRnC9PRGH\ny8eRk4foj31XcTWNz6IBe4mNUpun6Gker6o8ahEvhbRM7FLCzqLC2zXldT+KCYUv\nYHhZ+3jIWNoPuYa6gqgJbF0WTcNS2bttEw==\n-----END CERTIFICATE-----",
                        },
                    },
                    {
                        format: "download",
                        label: "download link",
                        value: {
                            type: "link",
                            data: "img/logo.png",
                            filename: "openxpki.png",
                        },
                    },
                    {
                        format: "raw",
                        label: "raw",
                        value: "Link to <a href=\"https://www.openxpki.org\">OpenXPKI</a>",
                    },
                    {
                        format: "deflist",
                        label: "deflist",
                        value: [
                            { label: "first", value: "PKI <a href=\"should be escaped\">" },
                            { label: "second", value: "<a href=\"https://www.openxpki.org\">OpenXPKI</a>", format: "raw" },
                            { label: "subject", value: [ "CN=sista.example.org", "DC=Test Deployment", "DC=PKI Examples", "DC=OpenXPKI", "DC=org" ] },
                        ],
                    },
                    {
                        format: "deflist",
                        label: "deflist-arbitrary",
                        value: [
                            {
                                label: "hosts-by-group",
                                value: {
                                    'one-two-three': [
                                        "first.loooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-oooooooooooooooooooo-example.org",
                                        "second.example.org"
                                    ],
                                },
                            },
                            {
                                label: "size",
                                value: "1234"
                            },
                        ],
                    },
                    {
                        format: "ullist",
                        label: "ullist",
                        value: [ "PKI", "OpenXPKI" ],
                    },
                    {
                        format: "rawlist",
                        label: "rawlist",
                        value: [ "PKI", "<a href=\"https://www.openxpki.org\">OpenXPKI</a>" ],
                    },
                    {
                        format: "linklist",
                        label: "linklist",
                        value: [
                            {
                                label: "Workflow History",
                                page: "workflow!history!wf_id!13567",
                                tooltip: "I feel like hovering",
                            },
                            {
                                label: "Technical Log",
                                page: "workflow!log!wf_id!13567",
                                tooltip: "I feel like hovering",
                            },
                            {
                                label: "Just a label (tooltip!)",
                                tooltip: "I feel like hovering",
                            }
                        ],
                    },
                    {
                        format: "styled",
                        label: "styled",
                        value: "attention:hear my words",
                    },
                    {
                        format: "tooltip",
                        label: "tooltip (short)",
                        value: {
                            value: "Hover me",
                            tooltip: "This is a short tooltip.",
                        },
                    },
                    {
                        format: "tooltip",
                        label: "tooltip (long)",
                        value: {
                            value: "Hover me",
                            tooltip: "This_is_intentionally_a_very_long_tooltip_text that came out of the blue. While it sprung into existence strange waves of gravity formed in a distant galaxy.",
                        },
                    },
                    {
                        format: "tooltip",
                        label: "tooltip (url - keyvalue)",
                        value: {
                            value: "Hover me for username",
                            tooltip_page: "tooltip!user!123",
                            tooltip_page_args: { test: 1 },
                        }
                    },
                    {
                        format: "tooltip",
                        label: "tooltip (url - chart)",
                        value: {
                            value: "Hover me for chart",
                            tooltip_page: "tooltip!chart",
                        }
                    },
                    {
                        format: "head",
                        label: "head",
                    },
                ],
            }
        },

        {
            type: "tiles",
            content: {
                label: "oxi-section/tiles",
                description: "",
                maxcol: 4,
                align: 'left',
                tiles: [
                    {
                        type: 'button', content: {
                            label: 'Request certificate',
                            image: 'img/request.png',
                            page: 'workflow!index!wf_type!certificate_signing_request_v2',
                        },
                    },
                    {
                        type: 'button', content: {
                            label: 'Revoke certificate',
                            image: 'img/revoke.png',
                            page: 'workflow!index!wf_type!certificate_revocation_request_v2',
                        },
                    },
                    { type: 'newline' },
                    {
                        type: 'button', content: {
                            label: 'SCEP Workflow Search',
                            image: 'img/transaction-id.png',
                            page: 'workflow!index!wf_type!search_scep_workflow',
                        },
                    },
                    {
                        type: 'button', content: {
                            label: 'My Certificates',
                            image: 'img/my-certificates.png',
                            page: 'certificate!mine',
                        },
                    },
                    {
                        type: 'button', content: {
                            label: 'Certificate Search',
                            image: 'img/certificate-search.png',
                            page: 'certificate!search',
                        },
                    },
                    {
                        type: 'button', content: {
                            label: 'CA Certificates',
                            image: 'img/get-issuers.png',
                            page: 'information!issuer',
                        },
                    },
                    {
                        type: 'button', content: {
                            label: 'Show Revocation Lists (CRL)',
                            image: 'img/get-crls.png',
                            page: 'crl!index',
                        },
                    },
                ],
            },
        },
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
