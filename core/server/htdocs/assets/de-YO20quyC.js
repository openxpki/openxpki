function _mergeNamespaces(n, m) {
	for (var i = 0; i < m.length; i++) {
		const e = m[i];
		if (typeof e !== 'string' && !Array.isArray(e)) { for (const k in e) {
			if (k !== 'default' && !(k in n)) {
				const d = Object.getOwnPropertyDescriptor(e, k);
				if (d) {
					Object.defineProperty(n, k, d.get ? d : {
						enumerable: true,
						get: () => e[k]
					});
				}
			}
		} }
	}
	return Object.freeze(Object.defineProperty(n, Symbol.toStringTag, { value: 'Module' }));
}

function getDefaultExportFromCjs (x) {
	return x && x.__esModule && Object.prototype.hasOwnProperty.call(x, 'default') ? x['default'] : x;
}

var de$3 = {exports: {}};

var de$2 = de$3.exports;

var hasRequiredDe;

function requireDe () {
	if (hasRequiredDe) return de$3.exports;
	hasRequiredDe = 1;
	(function (module, exports$1) {
		(function (global, factory) {
		  factory(exports$1) ;
		})(de$2, function (exports$1) {

		  var fp = typeof window !== "undefined" && window.flatpickr !== undefined ? window.flatpickr : {
		    l10ns: {}
		  };
		  var German = {
		    weekdays: {
		      shorthand: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"],
		      longhand: ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
		    },
		    months: {
		      shorthand: ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"],
		      longhand: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
		    },
		    firstDayOfWeek: 1,
		    weekAbbreviation: "KW",
		    rangeSeparator: " bis ",
		    scrollTitle: "Zum Ändern scrollen",
		    toggleTitle: "Zum Umschalten klicken",
		    time_24hr: true
		  };
		  fp.l10ns.de = German;
		  var de = fp.l10ns;
		  exports$1.German = German;
		  exports$1.default = de;
		  Object.defineProperty(exports$1, '__esModule', {
		    value: true
		  });
		}); 
	} (de$3, de$3.exports));
	return de$3.exports;
}

var deExports = requireDe();
const de = /*@__PURE__*/getDefaultExportFromCjs(deExports);

const de$1 = /*#__PURE__*/_mergeNamespaces({
	__proto__: null,
	default: de
}, [deExports]);

export { de$1 as d };
