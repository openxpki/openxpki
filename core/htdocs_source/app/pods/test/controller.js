import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';

export default class TestController extends Controller {
    @service('intl') intl;

    constructor() {
        super(...arguments);
        this.intl.setLocale(["de-de"]);
    }

    testButton = {
        label: "Button",
        format: "primary",
        tooltip: "This should do it",
        disabled: false,
    };

    @tracked formDef = {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            title: "Test input",
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
                    options: [
                        { value: 1, label: "Tusen" },
                        { value: 2, label: "Takk" },
                    ],
                },
                {
                    type: "select",
                    name: "test_select_2",
                    label: "Select, one choice",
                    options: [
                        { value: "11", label: "Ocean" },
                    ],
                    value: "",
                },
                {
                    type: "password",
                    name: "pwd",
                    label: "Password",
                },
                {
                    type: "passwordverify",
                    name: "pwd_verified",
                    label: "Password, verifiable",
                },
                {
                    type: "passwordverify",
                    name: "pwd_verified",
                    label: "Password, verifiable, preset",
                    value: "123\n",
                },
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
                    label: "Date, 2020-03-03 03:33",
                    timezone: "local",
                    value: "1583206380",
                },
                {
                    type: "datetime",
                    name: "dt_some",
                    label: "Date, 2020-03-03 03:33",
                    value: "1583206380",
                },
                {
                    type: "datetime",
                    name: "dt_some_local",
                    label: "Date, 2020-03-03 03:33",
                    value: "1583206380",
                    timezone: "Pacific/Pitcairn",
                },
                {
                    type: "text",
                    name: "plaintext",
                    label: "Clone field with 2 presets",
                    value: ["sheep #1", "sheep #2"],
                    clonable: 1,
                },
                {
                    type: "text",
                    name: "attributes",
                    label: "Dynamic, clonable, 2 presets",
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
                {
                    type: "static",
                    name: "label1",
                    label: "Label",
                    value: "on my shirt",
                },
                {
                    type: "static",
                    name: "label2",
                    label: "Label",
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
                    value: "...data...",
                    label: "Uploadarea",
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
                this.testButton,
                {
                    ...this.testButton,
                    label: "With confirmation",
                    confirm: {
                        label: "Really sure?",
                        description: "Think about it one more time.",
                    },
                },
                {
                    ...this.testButton,
                    label: "Disabled",
                    disabled: true,
                },
            ],
        }
    };

    @tracked gridDef = {
        "content": {
            "pager": {
                "startat": 0,
                "count": 2,
                "pagersize": 5,
                "pagesizes": [ 10, 20, 50 ],
                "limit": 10,
                "pagerurl": "certificate!pager!id!rJdrIbg1P6xsE6b9RtQCXp291SE",
                "order": "notbefore",
                "reverse": 0,
            },
            "empty": "No data available",
            "buttons": [
                {
                    "section": "Some",
                },
                {
                    "format": "expected",
                    "page": "certificate!search!query!rJdrIbg1P6xsE6b9RtQCXp291SE",
                    "label": "Reload Search Form",
                    "description": "Button 1",
                },
                {
                    "format": "alternative",
                    "page": "redirect!certificate!result!id!rJdrIbg1P6xsE6b9RtQCXp291SE",
                    "label": "Refresh Result",
                    "description": "Button 2",
                },
                {
                    "section": "Others",
                },
                {
                    "label": "New Search",
                    "format": "failure",
                    "page": "certificate!search"
                },
                {
                    "label": "Export Result",
                    "format": "optional",
                    "target": "_blank",
                    "href": "/cgi-bin/webui.fcgi?page=certificate!export!id!rJdrIbg1P6xsE6b9RtQCXp291SE"
                }
            ],
            "actions": [
                {
                    "label": "Download",
                    "icon": "download",
                    "path": "certificate!detail!identifier!{identifier}",
                    "target": "popup"
                },
                {
                    "label": "Check",
                    "icon": "download",
                    "path": "certificate!detail!identifier!{identifier}",
                    "target": "popup"
                }
            ],
            "columns": [
                {
                    "sTitle": "Certificate Serial",
                    "sortkey": "cert_key"
                },
                {
                    "sTitle": "Subject",
                    "sortkey": "subject"
                },
                {
                    "format": "certstatus",
                    "sortkey": "status",
                    "sTitle": "Status"
                },
                {
                    "sTitle": "not before",
                    "sortkey": "notbefore",
                    "format": "timestamp"
                },
                {
                    "format": "raw",
                    "sortkey": "notafter",
                    "sTitle": "raw"
                },
                {
                    "sortkey": "identifier",
                    "sTitle": "Certificate Identifier"
                },
                {
                    "sTitle": "identifier",
                    "bVisible": 0
                },
                {
                    "sTitle": "_className"
                },
            ],
            "data": [
                [
                    "0x3ff536fff8da93943aa",
                    "CN=e.d.c:pkiclient,DC=Test Deployment,DC=OpenXPKI,DC=org",
                    {
                        "value": "ISSUED",
                        "label": "Issued"
                    },
                    "1585959633",
                    1617495633,
                    "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                    "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    }
                ],
                [
                    "0x2ff8fa8ee5590e2553a",
                    "CN=sista.example.org:pkiclient,DC=Test Deployment,DC=OpenXPKI,DC=org",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    },
                    "1585434533",
                    "<a href=\"test\" onclick=\"alert('huh')\">test</a>",
                    "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                    "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    }
                ],
            ]
        },
        "type": "grid",
        "className": "certificate"
    };


    @tracked keyvalueDef = {
        "type": "keyvalue",
        "content": {
            "label": "oxisection-keyvalue",
            "description": "",
            "data": [
                {
                    "format": "certstatus",
                    "label": "certstatus",
                    "value": {
                        "value": "issued",
                        "label": "<i>Issued</i>",
                        "tooltip": "It's issued",
                    },
                },
                {
                    "format": "link",
                    "label": "link",
                    "value": {
                        "page": "workflow!load!wf_id!13567",
                        "label": 13567,
                        "target": "_blank",
                    },
                },
                {
                    "format": "extlink",
                    "label": "extlink",
                    "value": {
                        "page": "https://www.openxpki.org",
                        "label": "OpenXPKI",
                        "target": "_blank",
                    },
                },
                {
                    "format": "timestamp",
                    "label": "timestamp",
                    "value": 1617495633,
                },
                {
                    "format": "text",
                    "label": "text",
                    "value": "Link to <a href=\"should be escaped\">OpenXPKI</a>",
                },
                {
                    "format": "text",
                    "label": "text_as_list",
                    "value": [ "CN=sista.example.org:pkiclient,", "DC=Test Deployment,", "DC=PKI Examples,", "DC=OpenXPKI,", "DC=org" ],
                },
                {
                    "format": "nl2br",
                    "label": "nl2br",
                    "value": "Link to <a href=\"should be escaped\">OpenXPKI</a>\nand a comment",
                },
                {
                    "format": "code",
                    "label": "code",
                    "value": "console.log('Hello world');",
                },
                {
                    "format": "asciidata",
                    "label": "asciidata",
                    "value": "-----BEGIN CERTIFICATE-----\nMIIGdTCCBF2gAwIBAgIKBf/x2/q69qfgJjANBgkqhkiG9w0BAQsFADBTMQswCQYD\nVQQGEwJERTERMA8GA1UECgwIT3BlblhQS0kxDDAKBgNVBAsMA1BLSTEjMCEGA1UE\nAwwaT3BlblhQS0kgRGVtbyBJc3N1aW5nIENBIDEwHhcNMjAwNDE1MTQzMjUyWhcN\nMjEwNDE1MTQzMjUyWjBqMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxHzAdBgoJkiaJk/IsZAEZFg9UZXN0IERlcGxveW1lbnQx\nGDAWBgNVBAMMD2EuYi5jOnBraWNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBANj1rNdqbwgOKzCE76VB6tL9oMoASVXZvmTYUGORu+NgsrdpeKiG\n1rateJkosjgcUYhSgBJzvMW/3ZjJ94s90mA9eieuHSeYyxb8CMzR/cAkTj4gYr04\nJh4Q5NWp2DU+lDGHK2VnfIdxlTQuFGu5N7BET5DfRjXIiiPjOeQhzrXoUzyU8D50\nCWVmTtQ18qLbQEOgyUgCPNCJGEglA5tGJg7vDm3LZRl8qc26ynSmUEzvq6tDreyG\n+9AsQti4qZg2FUypvI1TFjSDv+J5tyq471scPyDBYEQI/lnKo1HGH+6a0HFgUu7H\nDcOqz2kIv+kyAocS8fvUCM8c+MZWNwxh80MCAwEAAaOCAjIwggIuMIGABggrBgEF\nBQcBAQR0MHIwSgYIKwYBBQUHMAKGPmh0dHA6Ly9wa2kuZXhhbXBsZS5jb20vZG93\nbmxvYWQvT3BlblhQS0lfRGVtb19Jc3N1aW5nX0NBXzEuY2VyMCQGCCsGAQUFBzAB\nhhhodHRwOi8vb2NzcC5leGFtcGxlLmNvbS8wTQYDVR0jBEYwRIAUv47981hKI/BJ\npmcdFera3Ht0/GyhIaQfMB0xGzAZBgNVBAMMEk9wZW5YUEtJIFJvb3QgQ0EgMYIJ\nAKXvcf7VbanOMAwGA1UdEwEB/wQCMAAwTwYDVR0fBEgwRjBEoEKgQIY+aHR0cDov\nL3BraS5leGFtcGxlLmNvbS9kb3dubG9hZC9PcGVuWFBLSV9EZW1vX0lzc3Vpbmdf\nQ0FfMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwCQYDVR0SBAIwADAOBgNV\nHQ8BAf8EBAMCB4AwgagGA1UdIASBoDCBnTCBmgYDKgMEMIGSMCsGCCsGAQUFBwIB\nFh9odHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMCsGCCsGAQUFBwIBFh9o\ndHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMDYGCCsGAQUFBwICMCoaKFRo\naXMgaXMgYSBjb21tZW50IGZvciBwb2xpY3kgb2lkIDEuMi4zLjQwHQYDVR0OBBYE\nFCmEqRsgxL3M9npTB/UlYv/IBc1rMA0GCSqGSIb3DQEBCwUAA4ICAQAlRwaMKaI9\nMuM/gpu9QEiQNfAwTD9CO6fMEfcOv6yZIaNBWlw151XxDS5qysJ5ccQuo93Hhcwa\nbEnYG7v5MFMrKvg24RW3lzHo4PdMFTeKcnKbXPIprvtWlOEqwoezdNJBP9bdSGcS\nxUSuLBPYWKt73qmc1+n8dpJp2E3FijMSPoSDV+B52Tu2d7KjYnuRtbxhAEY6Lz+2\n9BZYf+k+FGrerGyV/rpQ/IoUqQsJbffUOld0ffi+BAegIx4Ml+hPBpxu+XR1xyE7\n5Y5lzSs0NBDB7wslcG6jNGTsse3k2WumOrmbdAX5ExoYg+HAReFywJiLOzC4vqup\nRE2H1hSY3jcPJOalIk/WIzFrLJ8DbaLR4GFaABQ9WkWD9GlWZIURdmB8A+0ufoW/\nEh4YgOSI0z15QrwboZrb403A8/rZ3LTDyQmbz4iM+LJIJ+c9QG+k1AHuWLUbeoc5\n/GbNTRRb5SQXaikbOnQG+U4vX8WZxnMl6lTYa9RykzUaemFRbq8Zm4bbWdFuSWHS\n9F/K+0i806MzOITE+W2EbY5Flx5riAarTr5utOrYL041SQz5qDfxoCSlRnC9PRGH\ny8eRk4foj31XcTWNz6IBe4mNUpun6Gker6o8ahEvhbRM7FLCzqLC2zXldT+KCYUv\nYHhZ+3jIWNoPuYa6gqgJbF0WTcNS2bttEw==\n-----END CERTIFICATE-----",
                },
                {
                    "format": "download",
                    "label": "download",
                    "value": {
                        data: "-----BEGIN CERTIFICATE-----\nMIIGdTCCBF2gAwIBAgIKBf/x2/q69qfgJjANBgkqhkiG9w0BAQsFADBTMQswCQYD\nVQQGEwJERTERMA8GA1UECgwIT3BlblhQS0kxDDAKBgNVBAsMA1BLSTEjMCEGA1UE\nAwwaT3BlblhQS0kgRGVtbyBJc3N1aW5nIENBIDEwHhcNMjAwNDE1MTQzMjUyWhcN\nMjEwNDE1MTQzMjUyWjBqMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxHzAdBgoJkiaJk/IsZAEZFg9UZXN0IERlcGxveW1lbnQx\nGDAWBgNVBAMMD2EuYi5jOnBraWNsaWVudDCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBANj1rNdqbwgOKzCE76VB6tL9oMoASVXZvmTYUGORu+NgsrdpeKiG\n1rateJkosjgcUYhSgBJzvMW/3ZjJ94s90mA9eieuHSeYyxb8CMzR/cAkTj4gYr04\nJh4Q5NWp2DU+lDGHK2VnfIdxlTQuFGu5N7BET5DfRjXIiiPjOeQhzrXoUzyU8D50\nCWVmTtQ18qLbQEOgyUgCPNCJGEglA5tGJg7vDm3LZRl8qc26ynSmUEzvq6tDreyG\n+9AsQti4qZg2FUypvI1TFjSDv+J5tyq471scPyDBYEQI/lnKo1HGH+6a0HFgUu7H\nDcOqz2kIv+kyAocS8fvUCM8c+MZWNwxh80MCAwEAAaOCAjIwggIuMIGABggrBgEF\nBQcBAQR0MHIwSgYIKwYBBQUHMAKGPmh0dHA6Ly9wa2kuZXhhbXBsZS5jb20vZG93\nbmxvYWQvT3BlblhQS0lfRGVtb19Jc3N1aW5nX0NBXzEuY2VyMCQGCCsGAQUFBzAB\nhhhodHRwOi8vb2NzcC5leGFtcGxlLmNvbS8wTQYDVR0jBEYwRIAUv47981hKI/BJ\npmcdFera3Ht0/GyhIaQfMB0xGzAZBgNVBAMMEk9wZW5YUEtJIFJvb3QgQ0EgMYIJ\nAKXvcf7VbanOMAwGA1UdEwEB/wQCMAAwTwYDVR0fBEgwRjBEoEKgQIY+aHR0cDov\nL3BraS5leGFtcGxlLmNvbS9kb3dubG9hZC9PcGVuWFBLSV9EZW1vX0lzc3Vpbmdf\nQ0FfMS5jcmwwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwCQYDVR0SBAIwADAOBgNV\nHQ8BAf8EBAMCB4AwgagGA1UdIASBoDCBnTCBmgYDKgMEMIGSMCsGCCsGAQUFBwIB\nFh9odHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMCsGCCsGAQUFBwIBFh9o\ndHRwOi8vcGtpLmV4YW1wbGUuY29tL2Nwcy5odG1sMDYGCCsGAQUFBwICMCoaKFRo\naXMgaXMgYSBjb21tZW50IGZvciBwb2xpY3kgb2lkIDEuMi4zLjQwHQYDVR0OBBYE\nFCmEqRsgxL3M9npTB/UlYv/IBc1rMA0GCSqGSIb3DQEBCwUAA4ICAQAlRwaMKaI9\nMuM/gpu9QEiQNfAwTD9CO6fMEfcOv6yZIaNBWlw151XxDS5qysJ5ccQuo93Hhcwa\nbEnYG7v5MFMrKvg24RW3lzHo4PdMFTeKcnKbXPIprvtWlOEqwoezdNJBP9bdSGcS\nxUSuLBPYWKt73qmc1+n8dpJp2E3FijMSPoSDV+B52Tu2d7KjYnuRtbxhAEY6Lz+2\n9BZYf+k+FGrerGyV/rpQ/IoUqQsJbffUOld0ffi+BAegIx4Ml+hPBpxu+XR1xyE7\n5Y5lzSs0NBDB7wslcG6jNGTsse3k2WumOrmbdAX5ExoYg+HAReFywJiLOzC4vqup\nRE2H1hSY3jcPJOalIk/WIzFrLJ8DbaLR4GFaABQ9WkWD9GlWZIURdmB8A+0ufoW/\nEh4YgOSI0z15QrwboZrb403A8/rZ3LTDyQmbz4iM+LJIJ+c9QG+k1AHuWLUbeoc5\n/GbNTRRb5SQXaikbOnQG+U4vX8WZxnMl6lTYa9RykzUaemFRbq8Zm4bbWdFuSWHS\n9F/K+0i806MzOITE+W2EbY5Flx5riAarTr5utOrYL041SQz5qDfxoCSlRnC9PRGH\ny8eRk4foj31XcTWNz6IBe4mNUpun6Gker6o8ahEvhbRM7FLCzqLC2zXldT+KCYUv\nYHhZ+3jIWNoPuYa6gqgJbF0WTcNS2bttEw==\n-----END CERTIFICATE-----",
                    },
                },
                {
                    "format": "download",
                    "label": "download link",
                    "value": {
                        type: "link",
                        data: "img/logo.png",
                        filename: "openxpki.png",
                    },
                },
                {
                    "format": "raw",
                    "label": "raw",
                    "value": "Link to <a href=\"https://www.openxpki.org\">OpenXPKI</a>",
                },
                {
                    "format": "deflist",
                    "label": "deflist",
                    "value": [
                        { "label": "first", "value": "PKI <a href=\"should be escaped\">" },
                        { "label": "second", "value": "<a href=\"https://www.openxpki.org\">OpenXPKI</a>", "format": "raw" },
                        { "label": "subject", "value": [ "CN=sista.example.org", "DC=Test Deployment", "DC=PKI Examples", "DC=OpenXPKI", "DC=org" ] },
                    ],
                },
                {
                    "format": "ullist",
                    "label": "ullist",
                    "value": [ "PKI", "OpenXPKI" ],
                },
                {
                    "format": "rawlist",
                    "label": "rawlist",
                    "value": [ "PKI", "<a href=\"https://www.openxpki.org\">OpenXPKI</a>" ],
                },
                {
                    "format": "linklist",
                    "label": "linklist",
                    "value": [
                        {
                            "label": "Workflow History",
                            "page": "workflow!history!wf_id!13567",
                        },
                        {
                            "label": "Technical Log",
                            "page": "workflow!log!wf_id!13567",
                        }
                    ],
                },
                {
                    "format": "styled",
                    "label": "styled",
                    "value": "attention:hear my words",
                },
                {
                    "format": "tooltip",
                    "label": "tooltip",
                    "value": {
                        "value": "Hover me",
                        "tooltip": "...to see more",
                    },
                },
                {
                    "format": "head",
                    "label": "head",
                },
            ],
        }
    };
}
