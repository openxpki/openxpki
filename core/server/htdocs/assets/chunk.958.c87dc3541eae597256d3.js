/*! For license information please see chunk.958.c87dc3541eae597256d3.js.LICENSE.txt */
(self.webpackChunk_ember_auto_import_=self.webpackChunk_ember_auto_import_||[]).push([[958],{6831:function(e){var t=Array.isArray
e.exports=function(){if(!arguments.length)return[]
var e=arguments[0]
return t(e)?e:[e]}},5005:function(e){e.exports=function(e){var t=e?e.length:0
return t?e[t-1]:void 0}},9150:function(e){function t(e){return(t="function"==typeof Symbol&&"symbol"==typeof Symbol.iterator?function(e){return typeof e}:function(e){return e&&"function"==typeof Symbol&&e.constructor===Symbol&&e!==Symbol.prototype?"symbol":typeof e})(e)}var n="__lodash_hash_undefined__",r=9007199254740991,i=/^\[object .+?Constructor\]$/,o=/^(?:0|[1-9]\d*)$/,s="object"==("undefined"==typeof global?"undefined":t(global))&&global&&global.Object===Object&&global,a="object"==("undefined"==typeof self?"undefined":t(self))&&self&&self.Object===Object&&self,u=s||a||Function("return this")()
function l(e,t,n){switch(n.length){case 0:return e.call(t)
case 1:return e.call(t,n[0])
case 2:return e.call(t,n[0],n[1])
case 3:return e.call(t,n[0],n[1],n[2])}return e.apply(t,n)}function c(e,t){return!(!e||!e.length)&&function(e,t,n){if(t!=t)return function(e,t,n,r){for(var i=e.length,o=-1;++o<i;)if(t(e[o],o,e))return o
return-1}(e,d)
for(var r=-1,i=e.length;++r<i;)if(e[r]===t)return r
return-1}(e,t)>-1}function f(e,t){for(var n=-1,r=t.length,i=e.length;++n<r;)e[i+n]=t[n]
return e}function d(e){return e!=e}function h(e,t){return e.has(t)}function p(e,t){return function(n){return e(t(n))}}var g,m=Array.prototype,v=Function.prototype,b=Object.prototype,y=u["__core-js_shared__"],k=(g=/[^.]+$/.exec(y&&y.keys&&y.keys.IE_PROTO||""))?"Symbol(src)_1."+g:"",w=v.toString,x=b.hasOwnProperty,T=b.toString,E=RegExp("^"+w.call(x).replace(/[\\^$.*+?()[\]{}|]/g,"\\$&").replace(/hasOwnProperty|(function).*?(?=\\\()| for .+?(?=\\\])/g,"$1.*?")+"$"),_=u.Symbol,C=p(Object.getPrototypeOf,Object),j=b.propertyIsEnumerable,N=m.splice,S=_?_.isConcatSpreadable:void 0,q=Object.getOwnPropertySymbols,M=Math.max,I=H(u,"Map"),R=H(Object,"create")
function O(e){var t=-1,n=e?e.length:0
for(this.clear();++t<n;){var r=e[t]
this.set(r[0],r[1])}}function A(e){var t=-1,n=e?e.length:0
for(this.clear();++t<n;){var r=e[t]
this.set(r[0],r[1])}}function L(e){var t=-1,n=e?e.length:0
for(this.clear();++t<n;){var r=e[t]
this.set(r[0],r[1])}}function P(e){var t=-1,n=e?e.length:0
for(this.__data__=new L;++t<n;)this.add(e[t])}function D(e,t){for(var n,r,i=e.length;i--;)if((n=e[i][0])===(r=t)||n!=n&&r!=r)return i
return-1}function F(e,t,n,r,i){var o=-1,s=e.length
for(n||(n=$),i||(i=[]);++o<s;){var a=e[o]
t>0&&n(a)?t>1?F(a,t-1,n,r,i):f(i,a):r||(i[i.length]=a)}return i}function B(e,n){var r,i,o=e.__data__
return("string"==(i=t(r=n))||"number"==i||"symbol"==i||"boolean"==i?"__proto__"!==r:null===r)?o["string"==typeof n?"string":"hash"]:o.map}function H(e,t){var n=function(e,t){return null==e?void 0:e[t]}(e,t)
return function(e){return!(!Z(e)||(t=e,k&&k in t))&&(V(e)||function(e){var t=!1
if(null!=e&&"function"!=typeof e.toString)try{t=!!(e+"")}catch(e){}return t}(e)?E:i).test(function(e){if(null!=e){try{return w.call(e)}catch(e){}try{return e+""}catch(e){}}return""}(e))
var t}(n)?n:void 0}O.prototype.clear=function(){this.__data__=R?R(null):{}},O.prototype.delete=function(e){return this.has(e)&&delete this.__data__[e]},O.prototype.get=function(e){var t=this.__data__
if(R){var r=t[e]
return r===n?void 0:r}return x.call(t,e)?t[e]:void 0},O.prototype.has=function(e){var t=this.__data__
return R?void 0!==t[e]:x.call(t,e)},O.prototype.set=function(e,t){return this.__data__[e]=R&&void 0===t?n:t,this},A.prototype.clear=function(){this.__data__=[]},A.prototype.delete=function(e){var t=this.__data__,n=D(t,e)
return!(n<0||(n==t.length-1?t.pop():N.call(t,n,1),0))},A.prototype.get=function(e){var t=this.__data__,n=D(t,e)
return n<0?void 0:t[n][1]},A.prototype.has=function(e){return D(this.__data__,e)>-1},A.prototype.set=function(e,t){var n=this.__data__,r=D(n,e)
return r<0?n.push([e,t]):n[r][1]=t,this},L.prototype.clear=function(){this.__data__={hash:new O,map:new(I||A),string:new O}},L.prototype.delete=function(e){return B(this,e).delete(e)},L.prototype.get=function(e){return B(this,e).get(e)},L.prototype.has=function(e){return B(this,e).has(e)},L.prototype.set=function(e,t){return B(this,e).set(e,t),this},P.prototype.add=P.prototype.push=function(e){return this.__data__.set(e,n),this},P.prototype.has=function(e){return this.__data__.has(e)}
var U=q?p(q,Object):re,Q=q?function(e){for(var t=[];e;)f(t,U(e)),e=C(e)
return t}:re
function $(e){return W(e)||Y(e)||!!(S&&e&&e[S])}function G(e,t){return!!(t=null==t?r:t)&&("number"==typeof e||o.test(e))&&e>-1&&e%1==0&&e<t}function z(e){if("string"==typeof e||function(e){return"symbol"==t(e)||K(e)&&"[object Symbol]"==T.call(e)}(e))return e
var n=e+""
return"0"==n&&1/e==-1/0?"-0":n}function Y(e){return function(e){return K(e)&&J(e)}(e)&&x.call(e,"callee")&&(!j.call(e,"callee")||"[object Arguments]"==T.call(e))}var W=Array.isArray
function J(e){return null!=e&&function(e){return"number"==typeof e&&e>-1&&e%1==0&&e<=r}(e.length)&&!V(e)}function V(e){var t=Z(e)?T.call(e):""
return"[object Function]"==t||"[object GeneratorFunction]"==t}function Z(e){var n=t(e)
return!!e&&("object"==n||"function"==n)}function K(e){return!!e&&"object"==t(e)}function X(e){return J(e)?function(e,t){var n=W(e)||Y(e)?function(e,t){for(var n=-1,r=Array(e);++n<e;)r[n]=t(n)
return r}(e.length,String):[],r=n.length,i=!!r
for(var o in e)i&&("length"==o||G(o,r))||n.push(o)
return n}(e):function(e){if(!Z(e))return function(e){var t=[]
if(null!=e)for(var n in Object(e))t.push(n)
return t}(e)
var t,n,r=(n=(t=e)&&t.constructor,t===("function"==typeof n&&n.prototype||b)),i=[]
for(var o in e)("constructor"!=o||!r&&x.call(e,o))&&i.push(o)
return i}(e)}var ee,te,ne=(ee=function(e,t){return null==e?{}:(t=function(e,t){for(var n=-1,r=e?e.length:0,i=Array(r);++n<r;)i[n]=t(e[n],n,e)
return i}(F(t,1),z),function(e,t){return function(e,t,n){for(var r=-1,i=t.length,o={};++r<i;){var s=t[r],a=e[s]
n(0,s)&&(o[s]=a)}return o}(e=Object(e),t,(function(t,n){return n in e}))}(e,function(e,t,n,r){var i=-1,o=c,s=!0,a=e.length,u=[],l=t.length
if(!a)return u
t.length>=200&&(o=h,s=!1,t=new P(t))
e:for(;++i<a;){var f=e[i],d=f
if(f=0!==f?f:0,s&&d==d){for(var p=l;p--;)if(t[p]===d)continue e
u.push(f)}else o(t,d,undefined)||u.push(f)}return u}(function(e){return function(e,t,n){var r=t(e)
return W(e)?r:f(r,n(e))}(e,X,Q)}(e),t)))},te=M(void 0===te?ee.length-1:te,0),function(){for(var e=arguments,t=-1,n=M(e.length-te,0),r=Array(n);++t<n;)r[t]=e[te+t]
t=-1
for(var i=Array(te+1);++t<te;)i[t]=e[t]
return i[te]=r,l(ee,this,i)})
function re(){return[]}e.exports=ne},916:function(e,t,n){var r
e=n.nmd(e),function(){"use strict"
var i,o="function"==typeof o?o:function(){var e=Object.create(null)
this.get=function(t){return e[t]},this.set=function(t,n){return e[t]=n,this},this.clear=function(){e=Object.create(null)}}
function s(e){return(s="function"==typeof Symbol&&"symbol"==typeof Symbol.iterator?function(e){return typeof e}:function(e){return e&&"function"==typeof Symbol&&e.constructor===Symbol&&e!==Symbol.prototype?"symbol":typeof e})(e)}function a(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")}function u(e,t){for(var n=0;n<t.length;n++){var r=t[n]
r.enumerable=r.enumerable||!1,r.configurable=!0,"value"in r&&(r.writable=!0),Object.defineProperty(e,r.key,r)}}function l(e,t,n){return t&&u(e.prototype,t),n&&u(e,n),e}function c(e){return function(e){if(Array.isArray(e))return d(e)}(e)||function(e){if("undefined"!=typeof Symbol&&null!=e[Symbol.iterator]||null!=e["@@iterator"])return Array.from(e)}(e)||f(e)||function(){throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.")}()}function f(e,t){if(e){if("string"==typeof e)return d(e,t)
var n=Object.prototype.toString.call(e).slice(8,-1)
return"Object"===n&&e.constructor&&(n=e.constructor.name),"Map"===n||"Set"===n?Array.from(e):"Arguments"===n||/^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)?d(e,t):void 0}}function d(e,t){(null==t||t>e.length)&&(t=e.length)
for(var n=0,r=new Array(t);n<t;n++)r[n]=e[n]
return r}!function(e){if("object"===("undefined"==typeof globalThis?"undefined":s(globalThis)))i=globalThis
else{var t=function(){i=this||self,delete e.prototype._T_}
this?t():(e.defineProperty(e.prototype,"_T_",{configurable:!0,get:t}),_T_)}}(Object)
var h=i,p=h.window,g=h.self,m=h.console,v=h.setTimeout,b=h.clearTimeout,y=p&&p.document,k=p&&p.navigator,w=function(){var e="qunit-test-string"
try{return h.sessionStorage.setItem(e,e),h.sessionStorage.removeItem(e),h.sessionStorage}catch(e){return}}(),x={warn:m?Function.prototype.bind.call(m.warn||m.log,m):function(){}},T=Object.prototype.toString,E=Object.prototype.hasOwnProperty,_=Date.now||function(){return(new Date).getTime()},C=p&&void 0!==p.performance&&"function"==typeof p.performance.mark&&"function"==typeof p.performance.measure?p.performance:void 0,j={now:C?C.now.bind(C):_,measure:C?function(e,t,n){try{C.measure(e,t,n)}catch(e){x.warn("performance.measure could not be executed because of ",e.message)}}:function(){},mark:C?C.mark.bind(C):function(){}}
function N(e,t){for(var n=e.slice(),r=0;r<n.length;r++)for(var i=0;i<t.length;i++)if(n[r]===t[i]){n.splice(r,1),r--
break}return n}function S(e,t){return-1!==t.indexOf(e)}function q(e){var t=R("array",e)?[]:{}
for(var n in e)if(E.call(e,n)){var r=e[n]
t[n]=r===Object(r)?q(r):r}return t}function M(e,t,n){for(var r in t)E.call(t,r)&&(void 0===t[r]?delete e[r]:n&&void 0!==e[r]||(e[r]=t[r]))
return e}function I(e){if(void 0===e)return"undefined"
if(null===e)return"null"
var t=T.call(e).match(/^\[object\s(.*)\]$/),n=t&&t[1]
switch(n){case"Number":return isNaN(e)?"nan":"number"
case"String":case"Boolean":case"Array":case"Set":case"Map":case"Date":case"RegExp":case"Function":case"Symbol":return n.toLowerCase()
default:return s(e)}}function R(e,t){return I(t)===e}function O(e,t){for(var n=e+""+t,r=0,i=0;i<n.length;i++)r=(r<<5)-r+n.charCodeAt(i),r|=0
var o=(4294967296+r).toString(16)
return o.length<8&&(o="0000000"+o),o.slice(-8)}var A=function(){var e=[],t=Object.getPrototypeOf||function(e){return e.__proto__}
function n(e,t){return"object"===s(e)&&(e=e.valueOf()),"object"===s(t)&&(t=t.valueOf()),e===t}function r(e){return"flags"in e?e.flags:e.toString().match(/[gimuy]*$/)[0]}function i(t,n){return t===n||(-1===["object","array","map","set"].indexOf(I(t))?a(t,n):(e.every((function(e){return e.a!==t||e.b!==n}))&&e.push({a:t,b:n}),!0))}var o={string:n,boolean:n,number:n,null:n,undefined:n,symbol:n,date:n,nan:function(){return!0},regexp:function(e,t){return e.source===t.source&&r(e)===r(t)},function:function(){return!1},array:function(e,t){var n=e.length
if(n!==t.length)return!1
for(var r=0;r<n;r++)if(!i(e[r],t[r]))return!1
return!0},set:function(t,n){if(t.size!==n.size)return!1
var r=!0
return t.forEach((function(t){if(r){var i=!1
n.forEach((function(n){if(!i){var r=e
u(n,t)&&(i=!0),e=r}})),i||(r=!1)}})),r},map:function(t,n){if(t.size!==n.size)return!1
var r=!0
return t.forEach((function(t,i){if(r){var o=!1
n.forEach((function(n,r){if(!o){var s=e
u([n,r],[t,i])&&(o=!0),e=s}})),o||(r=!1)}})),r},object:function(e,n){if(!1===function(e,n){var r=t(e),i=t(n)
return e.constructor===n.constructor||(r&&null===r.constructor&&(r=null),i&&null===i.constructor&&(i=null),null===r&&i===Object.prototype||null===i&&r===Object.prototype)}(e,n))return!1
var r=[],o=[]
for(var s in e)if(r.push(s),(e.constructor===Object||void 0===e.constructor||"function"!=typeof e[s]||"function"!=typeof n[s]||e[s].toString()!==n[s].toString())&&!i(e[s],n[s]))return!1
for(var u in n)o.push(u)
return a(r.sort(),o.sort())}}
function a(e,t){var n=I(e)
return I(t)===n&&o[n](e,t)}function u(t,n){if(arguments.length<2)return!0
e=[{a:t,b:n}]
for(var r=0;r<e.length;r++){var i=e[r]
if(i.a!==i.b&&!a(i.a,i.b))return!1}return 2===arguments.length||u.apply(this,[].slice.call(arguments,1))}return function(){var t=u.apply(void 0,arguments)
return e.length=0,t}}(),L={queue:[],blocking:!0,failOnZeroTests:!0,reorder:!0,altertitle:!0,collapse:!0,scrolltop:!0,maxDepth:5,requireExpects:!1,urlConfig:[],modules:[],currentModule:{name:"",tests:[],childModules:[],testsRun:0,testsIgnored:0,hooks:{before:[],beforeEach:[],afterEach:[],after:[]}},callbacks:{},storage:w},P=p&&p.QUnit&&p.QUnit.config
p&&p.QUnit&&!p.QUnit.version&&M(L,P),L.modules.push(L.currentModule)
var D=function(){function e(e){return'"'+e.toString().replace(/\\/g,"\\\\").replace(/"/g,'\\"')+'"'}function t(e){return e+""}function n(e,t,n){var r=o.separator(),i=o.indent(1)
return t.join&&(t=t.join(","+r+i)),t?[e,i+t,o.indent()+n].join(r):e+n}function r(e,t){if(o.maxDepth&&o.depth>o.maxDepth)return"[object Array]"
this.up()
for(var r=e.length,i=new Array(r);r--;)i[r]=this.parse(e[r],void 0,t)
return this.down(),n("[",i,"]")}var i=/^function (\w+)/,o={parse:function(e,t,n){var r=(n=n||[]).indexOf(e)
if(-1!==r)return"recursion(".concat(r-n.length,")")
t=t||this.typeOf(e)
var i=this.parsers[t],o=s(i)
if("function"===o){n.push(e)
var a=i.call(this,e,n)
return n.pop(),a}return"string"===o?i:"[ERROR: Missing QUnit.dump formatter for type "+t+"]"},typeOf:function(e){return null===e?"null":void 0===e?"undefined":R("regexp",e)?"regexp":R("date",e)?"date":R("function",e)?"function":void 0!==e.setInterval&&void 0!==e.document&&void 0===e.nodeType?"window":9===e.nodeType?"document":e.nodeType?"node":function(e){return"[object Array]"===T.call(e)||"number"==typeof e.length&&void 0!==e.item&&(e.length?e.item(0)===e[0]:null===e.item(0)&&void 0===e[0])}(e)?"array":e.constructor===Error.prototype.constructor?"error":s(e)},separator:function(){return this.multiline?this.HTML?"<br />":"\n":this.HTML?"&#160;":" "},indent:function(e){if(!this.multiline)return""
var t=this.indentChar
return this.HTML&&(t=t.replace(/\t/g,"   ").replace(/ /g,"&#160;")),new Array(this.depth+(e||0)).join(t)},up:function(e){this.depth+=e||1},down:function(e){this.depth-=e||1},setParser:function(e,t){this.parsers[e]=t},quote:e,literal:t,join:n,depth:1,maxDepth:L.maxDepth,parsers:{window:"[Window]",document:"[Document]",error:function(e){return'Error("'+e.message+'")'},unknown:"[Unknown]",null:"null",undefined:"undefined",function:function(e){var t="function",r="name"in e?e.name:(i.exec(e)||[])[1]
return r&&(t+=" "+r),n(t=[t+="(",o.parse(e,"functionArgs"),"){"].join(""),o.parse(e,"functionCode"),"}")},array:r,nodelist:r,arguments:r,object:function(e,t){var r=[]
if(o.maxDepth&&o.depth>o.maxDepth)return"[object Object]"
o.up()
var i=[]
for(var s in e)i.push(s)
var a=["message","name"]
for(var u in a){var l=a[u]
l in e&&!S(l,i)&&i.push(l)}i.sort()
for(var c=0;c<i.length;c++){var f=i[c],d=e[f]
r.push(o.parse(f,"key")+": "+o.parse(d,void 0,t))}return o.down(),n("{",r,"}")},node:function(e){var t=o.HTML?"&lt;":"<",n=o.HTML?"&gt;":">",r=e.nodeName.toLowerCase(),i=t+r,s=e.attributes
if(s)for(var a=0,u=s.length;a<u;a++){var l=s[a].nodeValue
l&&"inherit"!==l&&(i+=" "+s[a].nodeName+"="+o.parse(l,"attribute"))}return i+=n,3!==e.nodeType&&4!==e.nodeType||(i+=e.nodeValue),i+t+"/"+r+n},functionArgs:function(e){var t=e.length
if(!t)return""
for(var n=new Array(t);t--;)n[t]=String.fromCharCode(97+t)
return" "+n.join(", ")+" "},key:e,functionCode:"[code]",attribute:e,string:e,date:e,regexp:t,number:t,boolean:t,symbol:function(e){return e.toString()}},HTML:!1,indentChar:"  ",multiline:!0}
return o}(),F=function(){function e(t,n){a(this,e),this.name=t,this.fullName=n?n.fullName.concat(t):[],this.tests=[],this.childSuites=[],n&&n.pushChildSuite(this)}return l(e,[{key:"start",value:function(e){if(e){this._startTime=j.now()
var t=this.fullName.length
j.mark("qunit_suite_".concat(t,"_start"))}return{name:this.name,fullName:this.fullName.slice(),tests:this.tests.map((function(e){return e.start()})),childSuites:this.childSuites.map((function(e){return e.start()})),testCounts:{total:this.getTestCounts().total}}}},{key:"end",value:function(e){if(e){this._endTime=j.now()
var t=this.fullName.length,n=this.fullName.join(" – ")
j.mark("qunit_suite_".concat(t,"_end")),j.measure(0===t?"QUnit Test Run":"QUnit Test Suite: ".concat(n),"qunit_suite_".concat(t,"_start"),"qunit_suite_".concat(t,"_end"))}return{name:this.name,fullName:this.fullName.slice(),tests:this.tests.map((function(e){return e.end()})),childSuites:this.childSuites.map((function(e){return e.end()})),testCounts:this.getTestCounts(),runtime:this.getRuntime(),status:this.getStatus()}}},{key:"pushChildSuite",value:function(e){this.childSuites.push(e)}},{key:"pushTest",value:function(e){this.tests.push(e)}},{key:"getRuntime",value:function(){return this._endTime-this._startTime}},{key:"getTestCounts",value:function(){var e=arguments.length>0&&void 0!==arguments[0]?arguments[0]:{passed:0,failed:0,skipped:0,todo:0,total:0}
return e=this.tests.reduce((function(e,t){return t.valid&&(e[t.getStatus()]++,e.total++),e}),e),this.childSuites.reduce((function(e,t){return t.getTestCounts(e)}),e)}},{key:"getStatus",value:function(){var e=this.getTestCounts(),t=e.total,n=e.failed,r=e.skipped,i=e.todo
return n?"failed":r===t?"skipped":i===t?"todo":"passed"}}]),e}(),B=[]
function H(e,t,n){var r=B.length?B.slice(-1)[0]:null,i=null!==r?[r.name,e].join(" > "):e,o=r?r.suiteReport:Be,s=null!==r&&r.skip||n.skip,a=null!==r&&r.todo||n.todo,u={name:i,parentModule:r,tests:[],moduleId:O(i),testsRun:0,testsIgnored:0,childModules:[],suiteReport:new F(e,o),skip:s,todo:!s&&a,ignored:n.ignored||!1},l={}
return r&&(r.childModules.push(u),M(l,r.testEnvironment)),M(l,t),u.testEnvironment=l,L.modules.push(u),u}function U(e,t,n){var r=arguments.length>3&&void 0!==arguments[3]?arguments[3]:{}
"function"===I(t)&&(n=t,t=void 0)
var i=H(e,t,r),o=i.testEnvironment,s=i.hooks={}
c(s,o,"before"),c(s,o,"beforeEach"),c(s,o,"afterEach"),c(s,o,"after")
var a={before:f(i,"before"),beforeEach:f(i,"beforeEach"),afterEach:f(i,"afterEach"),after:f(i,"after")},u=L.currentModule
if("function"===I(n)){B.push(i),L.currentModule=i
var l=n.call(i.testEnvironment,a)
null!=l&&"function"===I(l.then)&&x.warn("Returning a promise from a module callback is not supported. Instead, use hooks for async behavior. This will become an error in QUnit 3.0."),B.pop(),i=i.parentModule||u}function c(e,t,n){var r=t[n]
e[n]="function"==typeof r?[r]:[],delete t[n]}function f(e,t){return function(n){L.currentModule!==e&&x.warn("The `"+t+"` hook was called inside the wrong module. Instead, use hooks provided by the callback to the containing module. This will become an error in QUnit 3.0."),e.hooks[t].push(n)}}L.currentModule=i}var Q=!1
function $(e,t,n){var r
U(e,t,n,{ignored:Q&&(r=L.modules.filter((function(e){return!e.ignored})).map((function(e){return e.moduleId})),!B.some((function(e){return r.includes(e.moduleId)})))})}$.only=function(){Q||(L.modules.length=0,L.queue.length=0),U.apply(void 0,arguments),Q=!0},$.skip=function(e,t,n){Q||U(e,t,n,{skip:!0})},$.todo=function(e,t,n){Q||U(e,t,n,{todo:!0})}
var G=Object.create(null),z=["runStart","suiteStart","testStart","assertion","testEnd","suiteEnd","runEnd"]
function Y(e,t){if("string"!==I(e))throw new TypeError("eventName must be a string when emitting an event")
for(var n=G[e],r=n?c(n):[],i=0;i<r.length;i++)r[i](t)}var W="undefined"!=typeof globalThis?globalThis:"undefined"!=typeof window?window:"undefined"!=typeof global?global:"undefined"!=typeof self?self:{},J={exports:{}}
!function(){var e=function(){if("undefined"!=typeof globalThis)return globalThis
if("undefined"!=typeof self)return self
if("undefined"!=typeof window)return window
if(void 0!==W)return W
throw new Error("unable to locate global object")}()
if("function"!=typeof e.Promise){var t=setTimeout
i.prototype.catch=function(e){return this.then(null,e)},i.prototype.then=function(e,t){var n=new this.constructor(r)
return o(this,new c(e,t,n)),n},i.prototype.finally=function(e){var t=this.constructor
return this.then((function(n){return t.resolve(e()).then((function(){return n}))}),(function(n){return t.resolve(e()).then((function(){return t.reject(n)}))}))},i.all=function(e){return new i((function(t,r){if(!n(e))return r(new TypeError("Promise.all accepts an array"))
var i=Array.prototype.slice.call(e)
if(0===i.length)return t([])
var o=i.length
function a(e,n){try{if(n&&("object"===s(n)||"function"==typeof n)){var u=n.then
if("function"==typeof u)return void u.call(n,(function(t){a(e,t)}),r)}i[e]=n,0==--o&&t(i)}catch(e){r(e)}}for(var u=0;u<i.length;u++)a(u,i[u])}))},i.allSettled=function(e){return new this((function(t,n){if(!e||void 0===e.length)return n(new TypeError(s(e)+" "+e+" is not iterable(cannot read property Symbol(Symbol.iterator))"))
var r=Array.prototype.slice.call(e)
if(0===r.length)return t([])
var i=r.length
function o(e,n){if(n&&("object"===s(n)||"function"==typeof n)){var a=n.then
if("function"==typeof a)return void a.call(n,(function(t){o(e,t)}),(function(n){r[e]={status:"rejected",reason:n},0==--i&&t(r)}))}r[e]={status:"fulfilled",value:n},0==--i&&t(r)}for(var a=0;a<r.length;a++)o(a,r[a])}))},i.resolve=function(e){return e&&"object"===s(e)&&e.constructor===i?e:new i((function(t){t(e)}))},i.reject=function(e){return new i((function(t,n){n(e)}))},i.race=function(e){return new i((function(t,r){if(!n(e))return r(new TypeError("Promise.race accepts an array"))
for(var o=0,s=e.length;o<s;o++)i.resolve(e[o]).then(t,r)}))},i._immediateFn="function"==typeof setImmediate&&function(e){setImmediate(e)}||function(e){t(e,0)},i._unhandledRejectionFn=function(e){"undefined"!=typeof console&&console&&console.warn("Possible Unhandled Promise Rejection:",e)},J.exports=i}else J.exports=e.Promise
function n(e){return Boolean(e&&void 0!==e.length)}function r(){}function i(e){if(!(this instanceof i))throw new TypeError("Promises must be constructed via new")
if("function"!=typeof e)throw new TypeError("not a function")
this._state=0,this._handled=!1,this._value=void 0,this._deferreds=[],f(e,this)}function o(e,t){for(;3===e._state;)e=e._value
0!==e._state?(e._handled=!0,i._immediateFn((function(){var n=1===e._state?t.onFulfilled:t.onRejected
if(null!==n){var r
try{r=n(e._value)}catch(e){return void u(t.promise,e)}a(t.promise,r)}else(1===e._state?a:u)(t.promise,e._value)}))):e._deferreds.push(t)}function a(e,t){try{if(t===e)throw new TypeError("A promise cannot be resolved with itself.")
if(t&&("object"===s(t)||"function"==typeof t)){var n=t.then
if(t instanceof i)return e._state=3,e._value=t,void l(e)
if("function"==typeof n)return void f((r=n,o=t,function(){r.apply(o,arguments)}),e)}e._state=1,e._value=t,l(e)}catch(t){u(e,t)}var r,o}function u(e,t){e._state=2,e._value=t,l(e)}function l(e){2===e._state&&0===e._deferreds.length&&i._immediateFn((function(){e._handled||i._unhandledRejectionFn(e._value)}))
for(var t=0,n=e._deferreds.length;t<n;t++)o(e,e._deferreds[t])
e._deferreds=null}function c(e,t,n){this.onFulfilled="function"==typeof e?e:null,this.onRejected="function"==typeof t?t:null,this.promise=n}function f(e,t){var n=!1
try{e((function(e){n||(n=!0,a(t,e))}),(function(e){n||(n=!0,u(t,e))}))}catch(e){if(n)return
n=!0,u(t,e)}}}()
var V=J.exports
function Z(e,t){var n=L.callbacks[e]
if("log"!==e)return n.reduce((function(e,n){return e.then((function(){return V.resolve(n(t))}))}),V.resolve([]))
n.map((function(e){return e(t)}))}var K=(ee(0)||"").replace(/(:\d+)+\)?/,"").replace(/.+\//,"")
function X(e,t){if(t=void 0===t?4:t,e&&e.stack){var n=e.stack.split("\n")
if(/^error$/i.test(n[0])&&n.shift(),K){for(var r=[],i=t;i<n.length&&-1===n[i].indexOf(K);i++)r.push(n[i])
if(r.length)return r.join("\n")}return n[t]}}function ee(e){var t=new Error
if(!t.stack)try{throw t}catch(e){t=e}return X(t,e)}var te,ne=0,re=[]
function ie(){var e,t
e=_(),L.depth=(L.depth||0)+1,oe(e),L.depth--,re.length||L.blocking||L.current||(L.blocking||L.queue.length||0!==L.depth?(t=L.queue.shift()(),re.push.apply(re,c(t)),ne>0&&ne--,ie()):function(){var e=L.storage
se.finished=!0
var t=_()-L.started,n=L.stats.all-L.stats.bad
if(0===L.stats.testCount&&!0===L.failOnZeroTests){if(L.filter&&L.filter.length)throw new Error('No tests matched the filter "'.concat(L.filter,'".'))
if(L.module&&L.module.length)throw new Error('No tests matched the module "'.concat(L.module,'".'))
if(L.moduleId&&L.moduleId.length)throw new Error('No tests matched the moduleId "'.concat(L.moduleId,'".'))
if(L.testId&&L.testId.length)throw new Error('No tests matched the testId "'.concat(L.testId,'".'))
throw new Error("No tests were run.")}Y("runEnd",Be.end(!0)),Z("done",{passed:n,failed:L.stats.bad,total:L.stats.all,runtime:t}).then((function(){if(e&&0===L.stats.bad)for(var t=e.length-1;t>=0;t--){var n=e.key(t)
0===n.indexOf("qunit-test-")&&e.removeItem(n)}}))}())}function oe(e){if(re.length&&!L.blocking){var t=_()-e
if(!v||L.updateRate<=0||t<L.updateRate){var n=re.shift()
V.resolve(n()).then((function(){re.length?oe(e):ie()}))}else v(ie)}}var se={finished:!1,add:function(e,t,n){if(t)L.queue.splice(ne++,0,e)
else if(n){te||(te=function(e){var t=parseInt(O(e),16)||-1
return function(){return t^=t<<13,t^=t>>>17,(t^=t<<5)<0&&(t+=4294967296),t/4294967296}}(n))
var r=Math.floor(te()*(L.queue.length-ne+1))
L.queue.splice(ne+r,0,e)}else L.queue.push(e)},advance:ie,taskCount:function(){return re.length}},ae=function(){function e(t,n,r){a(this,e),this.name=t,this.suiteName=n.name,this.fullName=n.fullName.concat(t),this.runtime=0,this.assertions=[],this.skipped=!!r.skip,this.todo=!!r.todo,this.valid=r.valid,this._startTime=0,this._endTime=0,n.pushTest(this)}return l(e,[{key:"start",value:function(e){return e&&(this._startTime=j.now(),j.mark("qunit_test_start")),{name:this.name,suiteName:this.suiteName,fullName:this.fullName.slice()}}},{key:"end",value:function(e){if(e&&(this._endTime=j.now(),j)){j.mark("qunit_test_end")
var t=this.fullName.join(" – ")
j.measure("QUnit Test: ".concat(t),"qunit_test_start","qunit_test_end")}return M(this.start(),{runtime:this.getRuntime(),status:this.getStatus(),errors:this.getFailedAssertions(),assertions:this.getAssertions()})}},{key:"pushAssertion",value:function(e){this.assertions.push(e)}},{key:"getRuntime",value:function(){return this._endTime-this._startTime}},{key:"getStatus",value:function(){return this.skipped?"skipped":(this.getFailedAssertions().length>0?this.todo:!this.todo)?this.todo?"todo":"passed":"failed"}},{key:"getFailedAssertions",value:function(){return this.assertions.filter((function(e){return!e.passed}))}},{key:"getAssertions",value:function(){return this.assertions.slice()}},{key:"slimAssertions",value:function(){this.assertions=this.assertions.map((function(e){return delete e.actual,delete e.expected,e}))}}]),e}()
function ue(e){if(this.expected=null,this.assertions=[],this.semaphore=0,this.module=L.currentModule,this.steps=[],this.timeout=void 0,this.data=void 0,this.withData=!1,M(this,e),this.module.skip?(this.skip=!0,this.todo=!1):this.module.todo&&!this.skip&&(this.todo=!0),!this.skip&&"function"!=typeof this.callback){var t=this.todo?"QUnit.todo":"QUnit.test"
throw new TypeError("You must provide a callback to ".concat(t,'("').concat(this.testName,'")'))}++ue.count,this.errorForStack=new Error,this.testReport=new ae(this.testName,this.module.suiteReport,{todo:this.todo,skip:this.skip,valid:this.valid()})
for(var n=0,r=this.module.tests;n<r.length;n++)this.module.tests[n].name===this.testName&&(this.testName+=" ")
this.testId=O(this.module.name,this.testName),this.module.tests.push({name:this.testName,testId:this.testId,skip:!!this.skip}),this.skip?(this.callback=function(){},this.async=!1,this.expected=0):this.assert=new Te(this)}function le(){if(!L.current)throw new Error("pushFailure() assertion outside test context, in "+ee(2))
var e=L.current
return e.pushFailure.apply(e,arguments)}function ce(){if(L.pollution=[],L.noglobals)for(var e in h)if(E.call(h,e)){if(/^qunit-test-output/.test(e))continue
L.pollution.push(e)}}ue.count=0,ue.prototype={get stack(){return X(this.errorForStack,2)},before:function(){var e=this,t=this.module
return function(e){for(var t=e,n=[];t&&0===t.testsRun;)n.push(t),t=t.parentModule
return n.reverse()}(t).reduce((function(e,t){return e.then((function(){return t.stats={all:0,bad:0,started:_()},Y("suiteStart",t.suiteReport.start(!0)),Z("moduleStart",{name:t.name,tests:t.tests})}))}),V.resolve([])).then((function(){return L.current=e,e.testEnvironment=M({},t.testEnvironment),e.started=_(),Y("testStart",e.testReport.start(!0)),Z("testStart",{name:e.testName,module:t.name,testId:e.testId,previousFailure:e.previousFailure}).then((function(){L.pollution||ce()}))}))},run:function(){if(L.current=this,this.callbackStarted=_(),L.notrycatch)e(this)
else try{e(this)}catch(e){this.pushFailure("Died on test #"+(this.assertions.length+1)+" "+this.stack+": "+(e.message||e),X(e,0)),ce(),L.blocking&&be(this)}function e(e){var t
t=e.withData?e.callback.call(e.testEnvironment,e.assert,e.data):e.callback.call(e.testEnvironment,e.assert),e.resolvePromise(t),0===e.timeout&&0!==e.semaphore&&le("Test did not finish synchronously even though assert.timeout( 0 ) was used.",ee(2))}},after:function(){!function(){var e=L.pollution
ce()
var t=N(L.pollution,e)
t.length>0&&le("Introduced global variable(s): "+t.join(", "))
var n=N(e,L.pollution)
n.length>0&&le("Deleted global variable(s): "+n.join(", "))}()},queueHook:function(e,t,n){var r=this,i=function(){var n=e.call(r.testEnvironment,r.assert)
r.resolvePromise(n,t)}
return function(){if("before"===t){if(0!==n.testsRun)return
r.preserveEnvironment=!0}if("after"!==t||function(e){return e.testsRun===ke(e).filter((function(e){return!e.skip})).length-1}(n)||!(L.queue.length>0||se.taskCount()>2))if(L.current=r,L.notrycatch)i()
else try{i()}catch(e){r.pushFailure(t+" failed on "+r.testName+": "+(e.message||e),X(e,0))}}},hooks:function(e){var t=[]
return this.skip||function n(r,i){if(i.parentModule&&n(r,i.parentModule),i.hooks[e].length)for(var o=0;o<i.hooks[e].length;o++)t.push(r.queueHook(i.hooks[e][o],e,i))}(this,this.module),t},finish:function(){if(L.current=this,this.callback=void 0,this.steps.length){var e=this.steps.join(", ")
this.pushFailure("Expected assert.verifySteps() to be called before end of test "+"after using assert.step(). Unverified steps: ".concat(e),this.stack)}L.requireExpects&&null===this.expected?this.pushFailure("Expected number of assertions to be defined, but expect() was not called.",this.stack):null!==this.expected&&this.expected!==this.assertions.length?this.pushFailure("Expected "+this.expected+" assertions, but "+this.assertions.length+" were run",this.stack):null!==this.expected||this.assertions.length||this.pushFailure("Expected at least one assertion, but none were run - call expect(0) to accept zero assertions.",this.stack)
var t=this.module,n=t.name,r=this.testName,i=!!this.skip,o=!!this.todo,s=0,a=L.storage
this.runtime=_()-this.started,L.stats.all+=this.assertions.length,L.stats.testCount+=1,t.stats.all+=this.assertions.length
for(var u=0;u<this.assertions.length;u++)this.assertions[u].result||(s++,L.stats.bad++,t.stats.bad++)
i?xe(t):function(e){for(e.testsRun++;e=e.parentModule;)e.testsRun++}(t),a&&(s?a.setItem("qunit-test-"+n+"-"+r,s):a.removeItem("qunit-test-"+n+"-"+r)),Y("testEnd",this.testReport.end(!0)),this.testReport.slimAssertions()
var l=this
return Z("testDone",{name:r,module:n,skipped:i,todo:o,failed:s,passed:this.assertions.length-s,total:this.assertions.length,runtime:i?0:this.runtime,assertions:this.assertions,testId:this.testId,get source(){return l.stack}}).then((function(){if(we(t)){for(var e=[t],n=t.parentModule;n&&we(n);)e.push(n),n=n.parentModule
return e.reduce((function(e,t){return e.then((function(){return function(e){return e.hooks={},Y("suiteEnd",e.suiteReport.end(!0)),Z("moduleDone",{name:e.name,tests:e.tests,failed:e.stats.bad,passed:e.stats.all-e.stats.bad,total:e.stats.all,runtime:_()-e.stats.started})}(t)}))}),V.resolve([]))}})).then((function(){L.current=void 0}))},preserveTestEnvironment:function(){this.preserveEnvironment&&(this.module.testEnvironment=this.testEnvironment,this.testEnvironment=M({},this.module.testEnvironment))},queue:function(){var e=this
if(this.valid()){var t=L.storage&&+L.storage.getItem("qunit-test-"+this.module.name+"-"+this.testName),n=L.reorder&&!!t
this.previousFailure=!!t,se.add((function(){return[function(){return e.before()}].concat(c(e.hooks("before")),[function(){e.preserveTestEnvironment()}],c(e.hooks("beforeEach")),[function(){e.run()}],c(e.hooks("afterEach").reverse()),c(e.hooks("after").reverse()),[function(){e.after()},function(){return e.finish()}])}),n,L.seed),se.finished&&se.advance()}else xe(this.module)},pushResult:function(e){if(this!==L.current){var t=e&&e.message||"",n=this&&this.testName||""
throw new Error("Assertion occurred after test finished.\n> Test: "+n+"\n> Message: "+t+"\n")}var r={module:this.module.name,name:this.testName,result:e.result,message:e.message,actual:e.actual,testId:this.testId,negative:e.negative||!1,runtime:_()-this.started,todo:!!this.todo}
if(E.call(e,"expected")&&(r.expected=e.expected),!e.result){var i=e.source||ee()
i&&(r.source=i)}this.logAssertion(r),this.assertions.push({result:!!e.result,message:e.message})},pushFailure:function(e,t,n){if(!(this instanceof ue))throw new Error("pushFailure() assertion outside test context, was "+ee(2))
this.pushResult({result:!1,message:e||"error",actual:n||null,source:t})},logAssertion:function(e){Z("log",e)
var t={passed:e.result,actual:e.actual,expected:e.expected,message:e.message,stack:e.source,todo:e.todo}
this.testReport.pushAssertion(t),Y("assertion",t)},resolvePromise:function(e,t){if(null!=e){var n=this,r=e.then
if("function"===I(r)){var i=ve(n),o=function(){i()}
L.notrycatch?r.call(e,o):r.call(e,o,(function(e){var r="Promise rejected "+(t?t.replace(/Each$/,""):"during")+' "'+n.testName+'": '+(e&&e.message||e)
n.pushFailure(r,X(e,0)),ce(),be(n)}))}}},valid:function(){var e=L.filter,t=/^(!?)\/([\w\W]*)\/(i?$)/.exec(e),n=L.module&&L.module.toLowerCase(),r=this.module.name+": "+this.testName
return!(!this.callback||!this.callback.validTest)||!(L.moduleId&&L.moduleId.length>0&&!function e(t){return S(t.moduleId,L.moduleId)||t.parentModule&&e(t.parentModule)}(this.module))&&!(L.testId&&L.testId.length>0&&!S(this.testId,L.testId))&&!(n&&!function e(t){return(t.name?t.name.toLowerCase():null)===n||!!t.parentModule&&e(t.parentModule)}(this.module))&&(!e||(t?this.regexFilter(!!t[1],t[2],t[3],r):this.stringFilter(e,r)))},regexFilter:function(e,t,n,r){return new RegExp(t,n).test(r)!==e},stringFilter:function(e,t){e=e.toLowerCase(),t=t.toLowerCase()
var n="!"!==e.charAt(0)
return n||(e=e.slice(1)),-1!==t.indexOf(e)?n:!n}}
var fe=!1
function de(e){fe||L.currentModule.ignored||new ue(e).queue()}function he(e){L.currentModule.ignored||(fe||(L.queue.length=0,fe=!0),new ue(e).queue())}function pe(e,t){de({testName:e,callback:t})}function ge(e,t){return"".concat(e," [").concat(t,"]")}function me(e,t){if(Array.isArray(e))e.forEach(t)
else{if("object"!==s(e)||null===e)throw new Error("test.each() expects an array or object as input, but\nfound ".concat(s(e)," instead."))
Object.keys(e).forEach((function(n){t(e[n],n)}))}}function ve(e){var t,n=!1
return e.semaphore+=1,L.blocking=!0,v&&("number"==typeof e.timeout?t=e.timeout:"number"==typeof L.testTimeout&&(t=L.testTimeout),"number"==typeof t&&t>0&&(L.timeoutHandler=function(t){return function(){L.timeout=null,le("Test took longer than ".concat(t,"ms; test timed out."),ee(2)),n=!0,be(e)}},b(L.timeout),L.timeout=v(L.timeoutHandler(t),t))),function(){n||(n=!0,e.semaphore-=1,ye(e))}}function be(e){e.semaphore=0,ye(e)}function ye(e){isNaN(e.semaphore)&&(e.semaphore=0,le("Invalid value on test.semaphore",ee(2))),e.semaphore>0||(e.semaphore<0&&(e.semaphore=0,le("Tried to restart test while already started (test's semaphore was 0 already)",ee(2))),v?(b(L.timeout),L.timeout=v((function(){e.semaphore>0||(b(L.timeout),L.timeout=null,Ge())}))):Ge())}function ke(e){for(var t=[].concat(e.tests),n=c(e.childModules);n.length;){var r=n.shift()
t.push.apply(t,r.tests),n.push.apply(n,c(r.childModules))}return t}function we(e){return e.testsRun+e.testsIgnored===ke(e).length}function xe(e){for(e.testsIgnored++;e=e.parentModule;)e.testsIgnored++}M(pe,{todo:function(e,t){de({testName:e,callback:t,todo:!0})},skip:function(e){de({testName:e,skip:!0})},only:function(e,t){he({testName:e,callback:t})},each:function(e,t,n){me(t,(function(t,r){de({testName:ge(e,r),callback:n,withData:!0,data:t})}))}}),pe.todo.each=function(e,t,n){me(t,(function(t,r){de({testName:ge(e,r),callback:n,todo:!0,withData:!0,data:t})}))},pe.skip.each=function(e,t){me(t,(function(t,n){de({testName:ge(e,n),skip:!0})}))},pe.only.each=function(e,t,n){me(t,(function(t,r){he({testName:ge(e,r),callback:n,withData:!0,data:t})}))}
var Te=function(){function e(t){a(this,e),this.test=t}return l(e,[{key:"timeout",value:function(e){if("number"!=typeof e)throw new Error("You must pass a number as the duration to assert.timeout")
var t
this.test.timeout=e,L.timeout&&(b(L.timeout),L.timeout=null,L.timeoutHandler&&this.test.timeout>0&&(t=this.test.timeout,b(L.timeout),L.timeout=v(L.timeoutHandler(t),t)))}},{key:"step",value:function(e){var t=e,n=!!e
this.test.steps.push(e),"undefined"===I(e)||""===e?t="You must provide a message to assert.step":"string"!==I(e)&&(t="You must provide a string value to assert.step",n=!1),this.pushResult({result:n,message:t})}},{key:"verifySteps",value:function(e,t){var n=this.test.steps.slice()
this.deepEqual(n,e,t),this.test.steps.length=0}},{key:"expect",value:function(e){if(1!==arguments.length)return this.test.expected
this.test.expected=e}},{key:"async",value:function(e){var t=this.test,n=!1,r=e
void 0===r&&(r=1)
var i=ve(t)
return function(){if(void 0===L.current)throw new Error('`assert.async` callback from test "'+t.testName+'" called after tests finished.')
L.current===t?n?t.pushFailure("Too many calls to the `assert.async` callback",ee(2)):(r-=1)>0||(n=!0,i()):L.current.pushFailure('`assert.async` callback from test "'+t.testName+'" was called during this test.')}}},{key:"push",value:function(t,n,r,i,o){return x.warn("assert.push is deprecated and will be removed in QUnit 3.0. Please use assert.pushResult instead (https://api.qunitjs.com/assert/pushResult)."),(this instanceof e?this:L.current.assert).pushResult({result:t,actual:n,expected:r,message:i,negative:o})}},{key:"pushResult",value:function(t){var n=this,r=n instanceof e&&n.test||L.current
if(!r)throw new Error("assertion outside test context, in "+ee(2))
return n instanceof e||(n=r.assert),n.test.pushResult(t)}},{key:"ok",value:function(e,t){t||(t=e?"okay":"failed, expected argument to be truthy, was: ".concat(D.parse(e))),this.pushResult({result:!!e,actual:e,expected:!0,message:t})}},{key:"notOk",value:function(e,t){t||(t=e?"failed, expected argument to be falsy, was: ".concat(D.parse(e)):"okay"),this.pushResult({result:!e,actual:e,expected:!1,message:t})}},{key:"true",value:function(e,t){this.pushResult({result:!0===e,actual:e,expected:!0,message:t})}},{key:"false",value:function(e,t){this.pushResult({result:!1===e,actual:e,expected:!1,message:t})}},{key:"equal",value:function(e,t,n){var r=t==e
this.pushResult({result:r,actual:e,expected:t,message:n})}},{key:"notEqual",value:function(e,t,n){var r=t!=e
this.pushResult({result:r,actual:e,expected:t,message:n,negative:!0})}},{key:"propEqual",value:function(e,t,n){e=q(e),t=q(t),this.pushResult({result:A(e,t),actual:e,expected:t,message:n})}},{key:"notPropEqual",value:function(e,t,n){e=q(e),t=q(t),this.pushResult({result:!A(e,t),actual:e,expected:t,message:n,negative:!0})}},{key:"deepEqual",value:function(e,t,n){this.pushResult({result:A(e,t),actual:e,expected:t,message:n})}},{key:"notDeepEqual",value:function(e,t,n){this.pushResult({result:!A(e,t),actual:e,expected:t,message:n,negative:!0})}},{key:"strictEqual",value:function(e,t,n){this.pushResult({result:t===e,actual:e,expected:t,message:n})}},{key:"notStrictEqual",value:function(e,t,n){this.pushResult({result:t!==e,actual:e,expected:t,message:n,negative:!0})}},{key:"throws",value:function(t,n,r){var i,o=!1,s=this instanceof e&&this.test||L.current
if("string"===I(n)){if(null!=r)throw new Error("throws/raises does not accept a string value for the expected argument.\nUse a non-string object value (e.g. regExp) instead if it's necessary.")
r=n,n=null}s.ignoreGlobalErrors=!0
try{t.call(s.testEnvironment)}catch(e){i=e}if(s.ignoreGlobalErrors=!1,i){var a=I(n)
if(n){if("regexp"===a)o=n.test(Ee(i)),n=String(n)
else if("function"===a&&void 0!==n.prototype&&i instanceof n)o=!0
else if("object"===a)o=i instanceof n.constructor&&i.name===n.name&&i.message===n.message,n=Ee(n)
else if("function"===a)try{o=!0===n.call({},i),n=null}catch(e){n=Ee(e)}}else o=!0}s.assert.pushResult({result:o,actual:i&&Ee(i),expected:n,message:r})}},{key:"rejects",value:function(t,n,r){var i=!1,o=this instanceof e&&this.test||L.current
if("string"===I(n)){if(void 0!==r)return r="assert.rejects does not accept a string value for the expected argument.\nUse a non-string object value (e.g. validator function) instead if necessary.",void o.assert.pushResult({result:!1,message:r})
r=n,n=void 0}var s=t&&t.then
if("function"===I(s)){var a=this.async()
return s.call(t,(function(){var e='The promise returned by the `assert.rejects` callback in "'+o.testName+'" did not reject.'
o.assert.pushResult({result:!1,message:e,actual:t}),a()}),(function(e){var t=I(n)
void 0===n?i=!0:"regexp"===t?(i=n.test(Ee(e)),n=String(n)):"function"===t&&e instanceof n?i=!0:"object"===t?(i=e instanceof n.constructor&&e.name===n.name&&e.message===n.message,n=Ee(n)):"function"===t?(i=!0===n.call({},e),n=null):(i=!1,r='invalid expected value provided to `assert.rejects` callback in "'+o.testName+'": '+t+"."),o.assert.pushResult({result:i,actual:e&&Ee(e),expected:n,message:r}),a()}))}var u='The value provided to `assert.rejects` in "'+o.testName+'" was not a promise.'
o.assert.pushResult({result:!1,message:u,actual:t})}}]),e}()
function Ee(e){var t=e.toString()
if("[object"===t.slice(0,7)){var n=e.name?String(e.name):"Error"
return e.message?"".concat(n,": ").concat(e.message):n}return t}Te.prototype.raises=Te.prototype.throws
var _e,Ce,je,Ne,Se=function(){function e(t){var n=arguments.length>1&&void 0!==arguments[1]?arguments[1]:{}
a(this,e),this.log=n.log||Function.prototype.bind.call(m.log,m),t.on("runStart",this.onRunStart.bind(this)),t.on("testStart",this.onTestStart.bind(this)),t.on("testEnd",this.onTestEnd.bind(this)),t.on("runEnd",this.onRunEnd.bind(this))}return l(e,[{key:"onRunStart",value:function(e){this.log("runStart",e)}},{key:"onTestStart",value:function(e){this.log("testStart",e)}},{key:"onTestEnd",value:function(e){this.log("testEnd",e)}},{key:"onRunEnd",value:function(e){this.log("runEnd",e)}}],[{key:"init",value:function(t,n){return new e(t,n)}}]),e}(),qe=!0
if("undefined"!=typeof process){var Me=process.env
_e=Me.FORCE_COLOR,Ce=Me.NODE_DISABLE_COLORS,je=Me.NO_COLOR,Ne=Me.TERM,qe=process.stdout&&process.stdout.isTTY}var Ie={enabled:!Ce&&null==je&&"dumb"!==Ne&&(null!=_e&&"0"!==_e||qe),reset:Oe(0,0),bold:Oe(1,22),dim:Oe(2,22),italic:Oe(3,23),underline:Oe(4,24),inverse:Oe(7,27),hidden:Oe(8,28),strikethrough:Oe(9,29),black:Oe(30,39),red:Oe(31,39),green:Oe(32,39),yellow:Oe(33,39),blue:Oe(34,39),magenta:Oe(35,39),cyan:Oe(36,39),white:Oe(37,39),gray:Oe(90,39),grey:Oe(90,39),bgBlack:Oe(40,49),bgRed:Oe(41,49),bgGreen:Oe(42,49),bgYellow:Oe(43,49),bgBlue:Oe(44,49),bgMagenta:Oe(45,49),bgCyan:Oe(46,49),bgWhite:Oe(47,49)}
function Re(e,t){for(var n,r=0,i="",o="";r<e.length;r++)i+=(n=e[r]).open,o+=n.close,~t.indexOf(n.close)&&(t=t.replace(n.rgx,n.close+n.open))
return i+t+o}function Oe(e,t){var n={open:"[".concat(e,"m"),close:"[".concat(t,"m"),rgx:new RegExp("\\x1b\\[".concat(t,"m"),"g")}
return function(t){return void 0!==this&&void 0!==this.has?(~this.has.indexOf(e)||(this.has.push(e),this.keys.push(n)),void 0===t?this:Ie.enabled?Re(this.keys,t+""):t+""):void 0===t?((r={has:[e],keys:[n]}).reset=Ie.reset.bind(r),r.bold=Ie.bold.bind(r),r.dim=Ie.dim.bind(r),r.italic=Ie.italic.bind(r),r.underline=Ie.underline.bind(r),r.inverse=Ie.inverse.bind(r),r.hidden=Ie.hidden.bind(r),r.strikethrough=Ie.strikethrough.bind(r),r.black=Ie.black.bind(r),r.red=Ie.red.bind(r),r.green=Ie.green.bind(r),r.yellow=Ie.yellow.bind(r),r.blue=Ie.blue.bind(r),r.magenta=Ie.magenta.bind(r),r.cyan=Ie.cyan.bind(r),r.white=Ie.white.bind(r),r.gray=Ie.gray.bind(r),r.grey=Ie.grey.bind(r),r.bgBlack=Ie.bgBlack.bind(r),r.bgRed=Ie.bgRed.bind(r),r.bgGreen=Ie.bgGreen.bind(r),r.bgYellow=Ie.bgYellow.bind(r),r.bgBlue=Ie.bgBlue.bind(r),r.bgMagenta=Ie.bgMagenta.bind(r),r.bgCyan=Ie.bgCyan.bind(r),r.bgWhite=Ie.bgWhite.bind(r),r):Ie.enabled?Re([n],t+""):t+""
var r}}var Ae=Object.prototype.hasOwnProperty
function Le(e){var t=arguments.length>1&&void 0!==arguments[1]?arguments[1]:4
if(void 0===e&&(e=String(e)),"number"!=typeof e||isFinite(e)||(e=String(e)),"number"==typeof e)return JSON.stringify(e)
if("string"==typeof e){var n=/['"\\/[{}\]\r\n]/,r=/[-?:,[\]{}#&*!|=>'"%@`]/,i=/(^\s|\s$)/,o=/^[\d._-]+$/,s=/^(true|false|y|n|yes|no|on|off)$/i
if(""===e||n.test(e)||r.test(e[0])||i.test(e)||o.test(e)||s.test(e)){if(!/\n/.test(e))return JSON.stringify(e)
var a=new Array(t+1).join(" "),u=e.match(/\n+$/),l=u?u[0].length:0
if(1===l){var c=e.replace(/\n$/,"").split("\n").map((function(e){return a+e}))
return"|\n"+c.join("\n")}var f=e.split("\n").map((function(e){return a+e}))
return"|+\n"+f.join("\n")}return e}return JSON.stringify(Pe(e),null,2)}function Pe(e){var t,n=arguments.length>1&&void 0!==arguments[1]?arguments[1]:[]
if(-1!==n.indexOf(e))return"[Circular]"
var r=Object.prototype.toString.call(e).replace(/^\[.+\s(.+?)]$/,"$1").toLowerCase()
switch(r){case"array":n.push(e),t=e.map((function(e){return Pe(e,n)})),n.pop()
break
case"object":n.push(e),t={},Object.keys(e).forEach((function(r){t[r]=Pe(e[r],n)})),n.pop()
break
default:t=e}return t}var De={console:Se,tap:function(){function e(t){var n=arguments.length>1&&void 0!==arguments[1]?arguments[1]:{}
a(this,e),this.log=n.log||Function.prototype.bind.call(m.log,m),this.testCount=0,t.on("runStart",this.onRunStart.bind(this)),t.on("testEnd",this.onTestEnd.bind(this)),t.on("runEnd",this.onRunEnd.bind(this))}return l(e,[{key:"onRunStart",value:function(e){this.log("TAP version 13")}},{key:"onTestEnd",value:function(e){var t=this
this.testCount=this.testCount+1,"passed"===e.status?this.log("ok ".concat(this.testCount," ").concat(e.fullName.join(" > "))):"skipped"===e.status?this.log(Ie.yellow("ok ".concat(this.testCount," # SKIP ").concat(e.fullName.join(" > ")))):"todo"===e.status?(this.log(Ie.cyan("not ok ".concat(this.testCount," # TODO ").concat(e.fullName.join(" > ")))),e.errors.forEach((function(e){return t.logError(e,"todo")}))):(this.log(Ie.red("not ok ".concat(this.testCount," ").concat(e.fullName.join(" > ")))),e.errors.forEach((function(e){return t.logError(e)})))}},{key:"onRunEnd",value:function(e){this.log("1..".concat(e.testCounts.total)),this.log("# pass ".concat(e.testCounts.passed)),this.log(Ie.yellow("# skip ".concat(e.testCounts.skipped))),this.log(Ie.cyan("# todo ".concat(e.testCounts.todo))),this.log(Ie.red("# fail ".concat(e.testCounts.failed)))}},{key:"logError",value:function(e,t){var n="  ---"
n+="\n  message: ".concat(Le(e.message||"failed")),n+="\n  severity: ".concat(Le(t||"failed")),Ae.call(e,"actual")&&(n+="\n  actual  : ".concat(Le(e.actual))),Ae.call(e,"expected")&&(n+="\n  expected: ".concat(Le(e.expected))),e.stack&&(n+="\n  stack: ".concat(Le(e.stack+"\n"))),n+="\n  ...",this.log(n)}}],[{key:"init",value:function(t,n){return new e(t,n)}}]),e}()},Fe={},Be=new F
L.currentModule.suiteReport=Be
var He=!1,Ue=!1
function Qe(){Ue=!0,v?v((function(){Ge()})):Ge()}function $e(){L.blocking=!1,se.advance()}function Ge(){if(L.started)$e()
else{L.started=_(),""===L.modules[0].name&&0===L.modules[0].tests.length&&L.modules.shift()
for(var e=L.modules.length,t=[],n=0;n<e;n++)t.push({name:L.modules[n].name,tests:L.modules[n].tests})
Y("runStart",Be.start(!0)),Z("begin",{totalTests:ue.count,modules:t}).then($e)}}Fe.isLocal=p&&p.location&&"file:"===p.location.protocol,Fe.version="2.16.0",M(Fe,{config:L,dump:D,equiv:A,reporters:De,is:R,objectType:I,on:function(e,t){if("string"!==I(e))throw new TypeError("eventName must be a string when registering a listener")
if(!S(e,z)){var n=z.join(", ")
throw new Error('"'.concat(e,'" is not a valid event; must be one of: ').concat(n,"."))}if("function"!==I(t))throw new TypeError("callback must be a function when registering a listener")
G[e]||(G[e]=[]),S(t,G[e])||G[e].push(t)},onError:function(e){for(var t=arguments.length,n=new Array(t>1?t-1:0),r=1;r<t;r++)n[r-1]=arguments[r]
if(L.current){if(L.current.ignoreGlobalErrors)return!0
le.apply(void 0,[e.message,e.stacktrace||e.fileName+":"+e.lineNumber].concat(n))}else pe("global failure",M((function(){le.apply(void 0,[e.message,e.stacktrace||e.fileName+":"+e.lineNumber].concat(n))}),{validTest:!0}))
return!1},onUnhandledRejection:function(e){var t={result:!1,message:e.message||"error",actual:e,source:e.stack||ee(3)},n=L.current
n?n.assert.pushResult(t):pe("global failure",M((function(e){e.pushResult(t)}),{validTest:!0}))},pushFailure:le,assert:Te.prototype,module:$,test:pe,todo:pe.todo,skip:pe.skip,only:pe.only,start:function(e){if(L.current)throw new Error("QUnit.start cannot be called inside a test context.")
var t=He
if(He=!0,Ue)throw new Error("Called start() while test already started running")
if(t||e>1)throw new Error("Called start() outside of a test context too many times")
if(L.autostart)throw new Error("Called start() outside of a test context when QUnit.config.autostart was true")
if(!L.pageLoaded)return L.autostart=!0,void(y||Fe.load())
Qe()},extend:function(){x.warn("QUnit.extend is deprecated and will be removed in QUnit 3.0. Please use Object.assign instead.")
for(var e=arguments.length,t=new Array(e),n=0;n<e;n++)t[n]=arguments[n]
return M.apply(this,t)},load:function(){L.pageLoaded=!0,M(L,{stats:{all:0,bad:0,testCount:0},started:0,updateRate:1e3,autostart:!0,filter:""},!0),Ue||(L.blocking=!1,L.autostart&&Qe())},stack:function(e){return ee(e=(e||0)+2)}}),function(e){var t=["begin","done","log","testStart","testDone","moduleStart","moduleDone"]
function n(e){return function(t){if("function"!==I(t))throw new Error("QUnit logging methods require a callback function as their first parameters.")
L.callbacks[e].push(t)}}for(var r=0,i=t.length;r<i;r++){var o=t[r]
"undefined"===I(L.callbacks[o])&&(L.callbacks[o]=[]),e[o]=n(o)}}(Fe),function(i){var o=!1
if(p&&y){if(p.QUnit&&p.QUnit.version)throw new Error("QUnit has already been defined.")
p.QUnit=i,o=!0}e&&e.exports&&(e.exports=i,e.exports.QUnit=i,o=!0),t&&(t.QUnit=i,o=!0),void 0===(r=function(){return i}.call(t,n,t,e))||(e.exports=r),i.config.autostart=!1,o=!0,g&&g.WorkerGlobalScope&&g instanceof g.WorkerGlobalScope&&(g.QUnit=i,o=!0),o||(h.QUnit=i)}(Fe),function(){if(p&&y){var e=Fe.config,t=Object.prototype.hasOwnProperty
Fe.begin((function(){if(!t.call(e,"fixture")){var n=y.getElementById("qunit-fixture")
n&&(e.fixture=n.cloneNode(!0))}})),Fe.testStart((function(){if(null!=e.fixture){var t=y.getElementById("qunit-fixture")
if("string"===s(e.fixture)){var n=y.createElement("div")
n.setAttribute("id","qunit-fixture"),n.innerHTML=e.fixture,t.parentNode.replaceChild(n,t)}else{var r=e.fixture.cloneNode(!0)
t.parentNode.replaceChild(r,t)}}}))}}(),function(){var e=void 0!==p&&p.location
if(e){var t=function(){var t,r,i,o,s=Object.create(null),a=e.search.slice(1).split("&"),u=a.length
for(t=0;t<u;t++)a[t]&&(i=n((r=a[t].split("="))[0]),o=1===r.length||n(r.slice(1).join("=")),s[i]=i in s?[].concat(s[i],o):o)
return s}()
Fe.urlParams=t,Fe.config.moduleId=[].concat(t.moduleId||[]),Fe.config.testId=[].concat(t.testId||[]),Fe.config.module=t.module,Fe.config.filter=t.filter,!0===t.seed?Fe.config.seed=Math.random().toString(36).slice(2):t.seed&&(Fe.config.seed=t.seed),Fe.config.urlConfig.push({id:"hidepassed",label:"Hide passed tests",tooltip:"Only show tests and assertions that fail. Stored as query-strings."},{id:"noglobals",label:"Check for Globals",tooltip:"Enabling this will test if any test introduces new properties on the global object (`window` in Browsers). Stored as query-strings."},{id:"notrycatch",label:"No try-catch",tooltip:"Enabling this will run tests outside of a try-catch block. Makes debugging exceptions in IE reasonable. Stored as query-strings."}),Fe.begin((function(){var e,n,r=Fe.config.urlConfig
for(e=0;e<r.length;e++)"string"!=typeof(n=Fe.config.urlConfig[e])&&(n=n.id),void 0===Fe.config[n]&&(Fe.config[n]=t[n])}))}function n(e){return decodeURIComponent(e.replace(/\+/g,"%20"))}}()
var ze={exports:{}}
!function(e){var t,n
t=W,n=function(){var e="undefined"==typeof window,t=new o,n=new o,r=[]
r.total=0
var i=[],a=[]
function u(){t.clear(),n.clear(),i=[],a=[]}function l(e){for(var t=-9007199254740991,n=e.length-1;n>=0;--n){var r=e[n]
if(null!==r){var i=r.score
i>t&&(t=i)}}return-9007199254740991===t?null:t}function c(e,t){var n=e[t]
if(void 0!==n)return n
var r=t
Array.isArray(t)||(r=t.split("."))
for(var i=r.length,o=-1;e&&++o<i;)e=e[r[o]]
return e}function f(e){return"object"===s(e)}var d=function(){var e=[],t=0,n={}
function r(){for(var n=0,r=e[n],i=1;i<t;){var o=i+1
n=i,o<t&&e[o].score<e[i].score&&(n=o),e[n-1>>1]=e[n],i=1+(n<<1)}for(var s=n-1>>1;n>0&&r.score<e[s].score;s=(n=s)-1>>1)e[n]=e[s]
e[n]=r}return n.add=function(n){var r=t
e[t++]=n
for(var i=r-1>>1;r>0&&n.score<e[i].score;i=(r=i)-1>>1)e[r]=e[i]
e[r]=n},n.poll=function(){if(0!==t){var n=e[0]
return e[0]=e[--t],r(),n}},n.peek=function(n){if(0!==t)return e[0]},n.replaceTop=function(t){e[0]=t,r()},n},h=d()
return function o(s){var p={single:function(e,t,n){return e?(f(e)||(e=p.getPreparedSearch(e)),t?(f(t)||(t=p.getPrepared(t)),((n&&void 0!==n.allowTypo?n.allowTypo:!s||void 0===s.allowTypo||s.allowTypo)?p.algorithm:p.algorithmNoTypo)(e,t,e[0])):null):null},go:function(e,t,n){if(!e)return r
var i=(e=p.prepareSearch(e))[0],o=n&&n.threshold||s&&s.threshold||-9007199254740991,a=n&&n.limit||s&&s.limit||9007199254740991,u=(n&&void 0!==n.allowTypo?n.allowTypo:!s||void 0===s.allowTypo||s.allowTypo)?p.algorithm:p.algorithmNoTypo,d=0,g=0,m=t.length
if(n&&n.keys)for(var v=n.scoreFn||l,b=n.keys,y=b.length,k=m-1;k>=0;--k){for(var w=t[k],x=new Array(y),T=y-1;T>=0;--T)(C=c(w,_=b[T]))?(f(C)||(C=p.getPrepared(C)),x[T]=u(e,C,i)):x[T]=null
x.obj=w
var E=v(x)
null!==E&&(E<o||(x.score=E,d<a?(h.add(x),++d):(++g,E>h.peek().score&&h.replaceTop(x))))}else if(n&&n.key){var _=n.key
for(k=m-1;k>=0;--k)(C=c(w=t[k],_))&&(f(C)||(C=p.getPrepared(C)),null!==(j=u(e,C,i))&&(j.score<o||(j={target:j.target,_targetLowerCodes:null,_nextBeginningIndexes:null,score:j.score,indexes:j.indexes,obj:w},d<a?(h.add(j),++d):(++g,j.score>h.peek().score&&h.replaceTop(j)))))}else for(k=m-1;k>=0;--k){var C,j;(C=t[k])&&(f(C)||(C=p.getPrepared(C)),null!==(j=u(e,C,i))&&(j.score<o||(d<a?(h.add(j),++d):(++g,j.score>h.peek().score&&h.replaceTop(j)))))}if(0===d)return r
var N=new Array(d)
for(k=d-1;k>=0;--k)N[k]=h.poll()
return N.total=d+g,N},goAsync:function(t,n,i){var o=!1,a=new Promise((function(a,u){if(!t)return a(r)
var h=(t=p.prepareSearch(t))[0],g=d(),m=n.length-1,v=i&&i.threshold||s&&s.threshold||-9007199254740991,b=i&&i.limit||s&&s.limit||9007199254740991,y=(i&&void 0!==i.allowTypo?i.allowTypo:!s||void 0===s.allowTypo||s.allowTypo)?p.algorithm:p.algorithmNoTypo,k=0,w=0
function x(){if(o)return u("canceled")
var s=Date.now()
if(i&&i.keys)for(var d=i.scoreFn||l,T=i.keys,E=T.length;m>=0;--m){for(var _=n[m],C=new Array(E),j=E-1;j>=0;--j)(q=c(_,S=T[j]))?(f(q)||(q=p.getPrepared(q)),C[j]=y(t,q,h)):C[j]=null
C.obj=_
var N=d(C)
if(null!==N&&!(N<v)&&(C.score=N,k<b?(g.add(C),++k):(++w,N>g.peek().score&&g.replaceTop(C)),m%1e3==0&&Date.now()-s>=10))return void(e?setImmediate(x):setTimeout(x))}else if(i&&i.key){for(var S=i.key;m>=0;--m)if((q=c(_=n[m],S))&&(f(q)||(q=p.getPrepared(q)),null!==(M=y(t,q,h))&&!(M.score<v)&&(M={target:M.target,_targetLowerCodes:null,_nextBeginningIndexes:null,score:M.score,indexes:M.indexes,obj:_},k<b?(g.add(M),++k):(++w,M.score>g.peek().score&&g.replaceTop(M)),m%1e3==0&&Date.now()-s>=10)))return void(e?setImmediate(x):setTimeout(x))}else for(;m>=0;--m){var q,M
if((q=n[m])&&(f(q)||(q=p.getPrepared(q)),null!==(M=y(t,q,h))&&!(M.score<v)&&(k<b?(g.add(M),++k):(++w,M.score>g.peek().score&&g.replaceTop(M)),m%1e3==0&&Date.now()-s>=10)))return void(e?setImmediate(x):setTimeout(x))}if(0===k)return a(r)
for(var I=new Array(k),R=k-1;R>=0;--R)I[R]=g.poll()
I.total=k+w,a(I)}e?setImmediate(x):x()}))
return a.cancel=function(){o=!0},a},highlight:function(e,t,n){if(null===e)return null
void 0===t&&(t="<b>"),void 0===n&&(n="</b>")
for(var r="",i=0,o=!1,s=e.target,a=s.length,u=e.indexes,l=0;l<a;++l){var c=s[l]
if(u[i]===l){if(o||(o=!0,r+=t),++i===u.length){r+=c+n+s.substr(l+1)
break}}else o&&(o=!1,r+=n)
r+=c}return r},prepare:function(e){if(e)return{target:e,_targetLowerCodes:p.prepareLowerCodes(e),_nextBeginningIndexes:null,score:null,indexes:null,obj:null}},prepareSlow:function(e){if(e)return{target:e,_targetLowerCodes:p.prepareLowerCodes(e),_nextBeginningIndexes:p.prepareNextBeginningIndexes(e),score:null,indexes:null,obj:null}},prepareSearch:function(e){if(e)return p.prepareLowerCodes(e)},getPrepared:function(e){if(e.length>999)return p.prepare(e)
var n=t.get(e)
return void 0!==n||(n=p.prepare(e),t.set(e,n)),n},getPreparedSearch:function(e){if(e.length>999)return p.prepareSearch(e)
var t=n.get(e)
return void 0!==t||(t=p.prepareSearch(e),n.set(e,t)),t},algorithm:function(e,t,n){for(var r=t._targetLowerCodes,o=e.length,s=r.length,u=0,l=0,c=0,f=0;;){if(n===r[l]){if(i[f++]=l,++u===o)break
n=e[0===c?u:c===u?u+1:c===u-1?u-1:u]}if(++l>=s)for(;;){if(u<=1)return null
if(0===c){if(n===e[--u])continue
c=u}else{if(1===c)return null
if((n=e[1+(u=--c)])===e[u])continue}l=i[(f=u)-1]+1
break}}u=0
var d=0,h=!1,g=0,m=t._nextBeginningIndexes
null===m&&(m=t._nextBeginningIndexes=p.prepareNextBeginningIndexes(t.target))
var v=l=0===i[0]?0:m[i[0]-1]
if(l!==s)for(;;)if(l>=s){if(u<=0){if(++d>o-2)break
if(e[d]===e[d+1])continue
l=v
continue}--u,l=m[a[--g]]}else if(e[0===d?u:d===u?u+1:d===u-1?u-1:u]===r[l]){if(a[g++]=l,++u===o){h=!0
break}++l}else l=m[l]
if(h)var b=a,y=g
else b=i,y=f
for(var k=0,w=-1,x=0;x<o;++x)w!==(l=b[x])-1&&(k-=l),w=l
for(h?0!==d&&(k+=-20):(k*=1e3,0!==c&&(k+=-20)),k-=s-o,t.score=k,t.indexes=new Array(y),x=y-1;x>=0;--x)t.indexes[x]=b[x]
return t},algorithmNoTypo:function(e,t,n){for(var r=t._targetLowerCodes,o=e.length,s=r.length,u=0,l=0,c=0;;){if(n===r[l]){if(i[c++]=l,++u===o)break
n=e[u]}if(++l>=s)return null}u=0
var f=!1,d=0,h=t._nextBeginningIndexes
if(null===h&&(h=t._nextBeginningIndexes=p.prepareNextBeginningIndexes(t.target)),(l=0===i[0]?0:h[i[0]-1])!==s)for(;;)if(l>=s){if(u<=0)break;--u,l=h[a[--d]]}else if(e[u]===r[l]){if(a[d++]=l,++u===o){f=!0
break}++l}else l=h[l]
if(f)var g=a,m=d
else g=i,m=c
for(var v=0,b=-1,y=0;y<o;++y)b!==(l=g[y])-1&&(v-=l),b=l
for(f||(v*=1e3),v-=s-o,t.score=v,t.indexes=new Array(m),y=m-1;y>=0;--y)t.indexes[y]=g[y]
return t},prepareLowerCodes:function(e){for(var t=e.length,n=[],r=e.toLowerCase(),i=0;i<t;++i)n[i]=r.charCodeAt(i)
return n},prepareBeginningIndexes:function(e){for(var t=e.length,n=[],r=0,i=!1,o=!1,s=0;s<t;++s){var a=e.charCodeAt(s),u=a>=65&&a<=90,l=u||a>=97&&a<=122||a>=48&&a<=57,c=u&&!i||!o||!l
i=u,o=l,c&&(n[r++]=s)}return n},prepareNextBeginningIndexes:function(e){for(var t=e.length,n=p.prepareBeginningIndexes(e),r=[],i=n[0],o=0,s=0;s<t;++s)i>s?r[s]=i:(i=n[++o],r[s]=void 0===i?t:i)
return r},cleanup:u,new:o}
return p}()},e.exports?e.exports=n():t.fuzzysort=n()}(ze)
var Ye=ze.exports,We={passedTests:0,failedTests:0,skippedTests:0,todoTests:0}
function Je(e){return e?(e+="").replace(/['"<>&]/g,(function(e){switch(e){case"'":return"&#039;"
case'"':return"&quot;"
case"<":return"&lt;"
case">":return"&gt;"
case"&":return"&amp;"}})):""}!function(){if(p&&y){var e=Fe.config,t=[],n=!1,r=Object.prototype.hasOwnProperty,i=C({filter:void 0,module:void 0,moduleId:void 0,testId:void 0})
Fe.begin((function(){var t,n,o,s,a,u,f,h,m,_,C;(u=w("qunit"))&&(u.setAttribute("role","main"),u.innerHTML="<h1 id='qunit-header'>"+Je(y.title)+"</h1><h2 id='qunit-banner'></h2><div id='qunit-testrunner-toolbar' role='navigation'></div>"+(!(t=Fe.config.testId)||t.length<=0?"":"<div id='qunit-filteredTest'>Rerunning selected tests: "+Je(t.join(", "))+" <a id='qunit-clearFilter' href='"+Je(i)+"'>Run all tests</a></div>")+"<h2 id='qunit-userAgent'></h2><ol id='qunit-tests'></ol>"),(n=w("qunit-header"))&&(n.innerHTML="<a href='"+Je(i)+"'>"+n.innerHTML+"</a> "),(o=w("qunit-banner"))&&(o.className=""),_=w("qunit-tests"),(C=w("qunit-testresult"))&&C.parentNode.removeChild(C),_&&(_.innerHTML="",(C=y.createElement("p")).id="qunit-testresult",C.className="result",_.parentNode.insertBefore(C,_),C.innerHTML='<div id="qunit-testresult-display">Running...<br />&#160;</div><div id="qunit-testresult-controls"></div><div class="clearfix"></div>',h=w("qunit-testresult-controls")),h&&h.appendChild(((m=y.createElement("button")).id="qunit-abort-tests-button",m.innerHTML="Abort",l(m,"click",x),m)),(s=w("qunit-userAgent"))&&(s.innerHTML="",s.appendChild(y.createTextNode("QUnit "+Fe.version+"; "+k.userAgent))),(a=w("qunit-testrunner-toolbar"))&&(a.appendChild(((f=y.createElement("span")).innerHTML=function(){var t,n,i,o,s,a=!1,u=e.urlConfig,l=""
for(t=0;t<u.length;t++)if("string"==typeof(i=e.urlConfig[t])&&(i={id:i,label:i}),o=Je(i.id),s=Je(i.tooltip),i.value&&"string"!=typeof i.value){if(l+="<label for='qunit-urlconfig-"+o+"' title='"+s+"'>"+i.label+": </label><select id='qunit-urlconfig-"+o+"' name='"+o+"' title='"+s+"'><option></option>",Fe.is("array",i.value))for(n=0;n<i.value.length;n++)l+="<option value='"+(o=Je(i.value[n]))+"'"+(e[i.id]===i.value[n]?(a=!0)&&" selected='selected'":"")+">"+o+"</option>"
else for(n in i.value)r.call(i.value,n)&&(l+="<option value='"+Je(n)+"'"+(e[i.id]===n?(a=!0)&&" selected='selected'":"")+">"+Je(i.value[n])+"</option>")
e[i.id]&&!a&&(l+="<option value='"+(o=Je(e[i.id]))+"' selected='selected' disabled='disabled'>"+o+"</option>"),l+="</select>"}else l+="<label for='qunit-urlconfig-"+o+"' title='"+s+"'><input id='qunit-urlconfig-"+o+"' name='"+o+"' type='checkbox'"+(i.value?" value='"+Je(i.value)+"'":"")+(e[i.id]?" checked='checked'":"")+" title='"+s+"' />"+Je(i.label)+"</label>"
return l}(),g(f,"qunit-url-config"),d(f.getElementsByTagName("input"),"change",E),d(f.getElementsByTagName("select"),"change",E),f)),a.appendChild(function(){var t,n,r,i,o=y.createElement("span")
return o.id="qunit-toolbar-filters",o.appendChild((t=y.createElement("form"),n=y.createElement("label"),r=y.createElement("input"),i=y.createElement("button"),g(t,"qunit-filter"),n.innerHTML="Filter: ",r.type="text",r.value=e.filter||"",r.name="filter",r.id="qunit-filter-input",i.innerHTML="Go",n.appendChild(r),t.appendChild(n),t.appendChild(y.createTextNode(" ")),t.appendChild(i),l(t,"submit",T),t)),o.appendChild(function(){var t,n,r,i=y.createElement("form"),o=y.createElement("label"),s=y.createElement("input"),a=y.createElement("div"),u=y.createElement("span"),f=y.createElement("button"),d=y.createElement("button"),h=y.createElement("label"),g=y.createElement("input"),m=y.createElement("ul"),k=!1
function w(){function e(t){var n=i.contains(t.target)
27!==t.keyCode&&n||(27===t.keyCode&&n&&s.focus(),a.style.display="none",c(y,"click",e),c(y,"keydown",e),s.value="",x())}"none"===a.style.display&&(a.style.display="block",l(y,"click",e),l(y,"keydown",e))}function x(){p.clearTimeout(r),r=p.setTimeout((function(){var t,n=""===(t=s.value.toLowerCase())?e.modules:Ye.go(t,e.modules,{key:"namePrepared",threshold:-1e4}).map((function(e){return e.obj}))
m.innerHTML=N(n)}),200)}function E(e){var r,i,o=e&&e.target||g,a=m.getElementsByTagName("input"),u=[]
for(v(o.parentNode,"checked",o.checked),k=!1,o.checked&&o!==g&&(g.checked=!1,b(g.parentNode,"checked")),r=0;r<a.length;r++)i=a[r],e?o===g&&o.checked&&(i.checked=!1,b(i.parentNode,"checked")):v(i.parentNode,"checked",i.checked),k=k||i.checked!==i.defaultChecked,i.checked&&u.push(i.parentNode.textContent)
t.style.display=n.style.display=k?"":"none",s.placeholder=u.join(", ")||g.parentNode.textContent,s.title="Type to filter list. Current selection:\n"+(u.join("\n")||g.parentNode.textContent)}return s.id="qunit-modulefilter-search",s.autocomplete="off",l(s,"input",x),l(s,"input",w),l(s,"focus",w),l(s,"click",w),e.modules.forEach((function(e){return e.namePrepared=Ye.prepare(e.name)})),o.id="qunit-modulefilter-search-container",o.innerHTML="Module: ",o.appendChild(s),f.textContent="Apply",f.style.display="none",d.textContent="Reset",d.type="reset",d.style.display="none",g.type="checkbox",g.checked=0===e.moduleId.length,h.className="clickable",e.moduleId.length&&(h.className="checked"),h.appendChild(g),h.appendChild(y.createTextNode("All modules")),u.id="qunit-modulefilter-actions",u.appendChild(f),u.appendChild(d),u.appendChild(h),t=u.firstChild,n=t.nextSibling,l(t,"click",j),m.id="qunit-modulefilter-dropdown-list",m.innerHTML=N(e.modules),a.id="qunit-modulefilter-dropdown",a.style.display="none",a.appendChild(u),a.appendChild(m),l(a,"change",E),E(),i.id="qunit-modulefilter",i.appendChild(o),i.appendChild(a),l(i,"submit",T),l(i,"reset",(function(){p.setTimeout(E)})),i}()),o}()),a.appendChild(y.createElement("div")).className="clearfix")})),Fe.done((function(t){var n,r,i,o=w("qunit-banner"),s=w("qunit-tests"),a=w("qunit-abort-tests-button"),u=[We.passedTests+We.skippedTests+We.todoTests+We.failedTests," tests completed in ",t.runtime," milliseconds, with ",We.failedTests," failed, ",We.skippedTests," skipped, and ",We.todoTests," todo.<br />","<span class='passed'>",t.passed,"</span> assertions of <span class='total'>",t.total,"</span> passed, <span class='failed'>",t.failed,"</span> failed."].join("")
if(a&&a.disabled){u="Tests aborted after "+t.runtime+" milliseconds."
for(var l=0;l<s.children.length;l++)""!==(n=s.children[l]).className&&"running"!==n.className||(n.className="aborted",i=n.getElementsByTagName("ol")[0],(r=y.createElement("li")).className="fail",r.innerHTML="Test aborted.",i.appendChild(r))}!o||a&&!1!==a.disabled||(o.className=We.failedTests?"qunit-fail":"qunit-pass"),a&&a.parentNode.removeChild(a),s&&(w("qunit-testresult-display").innerHTML=u),e.altertitle&&y.title&&(y.title=[We.failedTests?"✖":"✔",y.title.replace(/^[\u2714\u2716] /i,"")].join(" ")),e.scrolltop&&p.scrollTo&&p.scrollTo(0,0)})),Fe.testStart((function(t){var n,r,i,o,s,a,u,l,c,f
i=t.name,o=t.testId,s=t.module,(f=w("qunit-tests"))&&((a=y.createElement("strong")).innerHTML=S(i,s),(u=y.createElement("a")).innerHTML="Rerun",u.href=C({testId:o}),(l=y.createElement("li")).appendChild(a),l.appendChild(u),l.id="qunit-test-output-"+o,(c=y.createElement("ol")).className="qunit-assert-list",l.appendChild(c),f.appendChild(l)),(n=w("qunit-testresult-display"))&&(g(n,"running"),r=Fe.config.reorder&&t.previousFailure,n.innerHTML=[r?"Rerunning previously failed test: <br />":"Running: <br />",S(t.name,t.module),q(_()-e.started,We,ue.count)].join(""))})),Fe.log((function(e){var t,n,i,o,s,a,u=!1,l=w("qunit-test-output-"+e.testId)
l&&(i="<span class='test-message'>"+(i=Je(e.message)||(e.result?"okay":"failed"))+"</span>",i+="<span class='runtime'>@ "+e.runtime+" ms</span>",!e.result&&r.call(e,"expected")?(o=e.negative?"NOT "+Fe.dump.parse(e.expected):Fe.dump.parse(e.expected),s=Fe.dump.parse(e.actual),i+="<table><tr class='test-expected'><th>Expected: </th><td><pre>"+Je(o)+"</pre></td></tr>",s!==o?(i+="<tr class='test-actual'><th>Result: </th><td><pre>"+Je(s)+"</pre></td></tr>","number"==typeof e.actual&&"number"==typeof e.expected?isNaN(e.actual)||isNaN(e.expected)||(u=!0,a=((a=e.actual-e.expected)>0?"+":"")+a):"boolean"!=typeof e.actual&&"boolean"!=typeof e.expected&&(u=I(a=Fe.diff(o,s)).length!==I(o).length+I(s).length),u&&(i+="<tr class='test-diff'><th>Diff: </th><td><pre>"+a+"</pre></td></tr>")):-1!==o.indexOf("[object Array]")||-1!==o.indexOf("[object Object]")?i+="<tr class='test-message'><th>Message: </th><td>Diff suppressed as the depth of object is more than current max depth ("+Fe.config.maxDepth+").<p>Hint: Use <code>QUnit.dump.maxDepth</code> to  run with a higher max depth or <a href='"+Je(C({maxDepth:-1}))+"'>Rerun</a> without max depth.</p></td></tr>":i+="<tr class='test-message'><th>Message: </th><td>Diff suppressed as the expected and actual results have an equivalent serialization</td></tr>",e.source&&(i+="<tr class='test-source'><th>Source: </th><td><pre>"+Je(e.source)+"</pre></td></tr>"),i+="</table>"):!e.result&&e.source&&(i+="<table><tr class='test-source'><th>Source: </th><td><pre>"+Je(e.source)+"</pre></td></tr></table>"),t=l.getElementsByTagName("ol")[0],(n=y.createElement("li")).className=e.result?"pass":"fail",n.innerHTML=i,t.appendChild(n))})),Fe.testDone((function(r){var i,o,s,a,u,c,f,d,h,p=w("qunit-tests"),m=w("qunit-test-output-"+r.testId)
if(p&&m){b(m,"running"),a=r.failed>0?"failed":r.todo?"todo":r.skipped?"skipped":"passed",s=m.getElementsByTagName("ol")[0],u=r.passed,c=r.failed
var k=r.failed>0?r.todo:!r.todo
if(k?g(s,"qunit-collapsed"):e.collapse&&(n?g(s,"qunit-collapsed"):n=!0),f=c?"<b class='failed'>"+c+"</b>, <b class='passed'>"+u+"</b>, ":"",(i=m.firstChild).innerHTML+=" <b class='counts'>("+f+r.assertions.length+")</b>",r.skipped)We.skippedTests++,m.className="skipped",(d=y.createElement("em")).className="qunit-skipped-label",d.innerHTML="skipped",m.insertBefore(d,i)
else{if(l(i,"click",(function(){v(s,"qunit-collapsed")})),m.className=k?"pass":"fail",r.todo){var x=y.createElement("em")
x.className="qunit-todo-label",x.innerHTML="todo",m.className+=" todo",m.insertBefore(x,i)}(o=y.createElement("span")).className="runtime",o.innerHTML=r.runtime+" ms",m.insertBefore(o,s),k?r.todo?We.todoTests++:We.passedTests++:We.failedTests++}r.source&&((h=y.createElement("p")).innerHTML="<strong>Source: </strong>"+Je(r.source),g(h,"qunit-source"),k&&g(h,"qunit-collapsed"),l(i,"click",(function(){v(h,"qunit-collapsed")})),m.appendChild(h)),e.hidepassed&&("passed"===a||r.skipped)&&(t.push(m),p.removeChild(m))}}))
var o,s=(o=p.phantom)&&o.version&&o.version.major>0
s&&m.warn("Support for PhantomJS is deprecated and will be removed in QUnit 3.0."),s||"complete"!==y.readyState?l(p,"load",Fe.load):Fe.load()
var a=p.onerror
p.onerror=function(e,t,n,r,i){var o=!1
if(a){for(var s=arguments.length,u=new Array(s>5?s-5:0),l=5;l<s;l++)u[l-5]=arguments[l]
o=a.call.apply(a,[this,e,t,n,r,i].concat(u))}if(!0!==o){var c={message:e,fileName:t,lineNumber:n}
i&&i.stack&&(c.stacktrace=X(i,0)),o=Fe.onError(c)}return o},p.addEventListener("unhandledrejection",(function(e){Fe.onUnhandledRejection(e.reason)}))}function u(e){return"function"==typeof e.trim?e.trim():e.replace(/^\s+|\s+$/g,"")}function l(e,t,n){e.addEventListener(t,n,!1)}function c(e,t,n){e.removeEventListener(t,n,!1)}function d(e,t,n){for(var r=e.length;r--;)l(e[r],t,n)}function h(e,t){return(" "+e.className+" ").indexOf(" "+t+" ")>=0}function g(e,t){h(e,t)||(e.className+=(e.className?" ":"")+t)}function v(e,t,n){n||void 0===n&&!h(e,t)?g(e,t):b(e,t)}function b(e,t){for(var n=" "+e.className+" ";n.indexOf(" "+t+" ")>=0;)n=n.replace(" "+t+" "," ")
e.className=u(n)}function w(e){return y.getElementById&&y.getElementById(e)}function x(){var e=w("qunit-abort-tests-button")
return e&&(e.disabled=!0,e.innerHTML="Aborting..."),Fe.config.queue.length=0,!1}function T(e){var t=w("qunit-filter-input")
return t.value=u(t.value),j(),e&&e.preventDefault&&e.preventDefault(),!1}function E(){var n,r,i,o=this,s={}
if(r="selectedIndex"in o?o.options[o.selectedIndex].value||void 0:o.checked?o.defaultValue||!0:void 0,s[o.name]=r,n=C(s),"hidepassed"===o.name&&"replaceState"in p.history){if(Fe.urlParams[o.name]=r,e[o.name]=r||!1,i=w("qunit-tests")){var a=i.children.length,u=i.children
if(o.checked){for(var l=0;l<a;l++){var c=u[l],d=c?c.className:"",h=d.indexOf("pass")>-1,g=d.indexOf("skipped")>-1;(h||g)&&t.push(c)}var m,v=function(e,t){var n="undefined"!=typeof Symbol&&e[Symbol.iterator]||e["@@iterator"]
if(!n){if(Array.isArray(e)||(n=f(e))){n&&(e=n)
var r=0,i=function(){}
return{s:i,n:function(){return r>=e.length?{done:!0}:{done:!1,value:e[r++]}},e:function(e){throw e},f:i}}throw new TypeError("Invalid attempt to iterate non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.")}var o,s=!0,a=!1
return{s:function(){n=n.call(e)},n:function(){var e=n.next()
return s=e.done,e},e:function(e){a=!0,o=e},f:function(){try{s||null==n.return||n.return()}finally{if(a)throw o}}}}(t)
try{for(v.s();!(m=v.n()).done;){var b=m.value
i.removeChild(b)}}catch(e){v.e(e)}finally{v.f()}}else for(;null!=(c=t.pop());)i.appendChild(c)}p.history.replaceState(null,"",n)}else p.location=n}function C(e){var t,n,i,o="?",s=p.location
for(t in e=M(M({},Fe.urlParams),e))if(r.call(e,t)&&void 0!==e[t])for(n=[].concat(e[t]),i=0;i<n.length;i++)o+=encodeURIComponent(t),!0!==n[i]&&(o+="="+encodeURIComponent(n[i])),o+="&"
return s.protocol+"//"+s.host+s.pathname+o.slice(0,-1)}function j(){var e,t=[],n=w("qunit-modulefilter-dropdown-list").getElementsByTagName("input"),r=w("qunit-filter-input").value
for(e=0;e<n.length;e++)n[e].checked&&t.push(n[e].value)
p.location=C({filter:""===r?void 0:r,moduleId:0===t.length?void 0:t,module:void 0,testId:void 0})}function N(t){var n,r,i=""
for(n=0;n<t.length;n++)""!==t[n].name&&(i+="<li><label class='clickable"+((r=e.moduleId.indexOf(t[n].moduleId)>-1)?" checked":"")+"'><input type='checkbox' value='"+t[n].moduleId+"'"+(r?" checked='checked'":"")+" />"+Je(t[n].name)+"</label></li>")
return i}function S(e,t){var n=""
return t&&(n="<span class='module-name'>"+Je(t)+"</span>: "),n+"<span class='test-name'>"+Je(e)+"</span>"}function q(e,t,n){return["<br />",t.passedTests+t.skippedTests+t.todoTests+t.failedTests," / ",n," tests completed in ",e," milliseconds, with ",t.failedTests," failed, ",t.skippedTests," skipped, and ",t.todoTests," todo."].join("")}function I(e){return e.replace(/<\/?[^>]+(>|$)/g,"").replace(/&quot;/g,"").replace(/\s+/g,"")}}(),Fe.diff=function(){function e(){}var t=-1,n=Object.prototype.hasOwnProperty
return e.prototype.DiffMain=function(e,t,n){var r,i,o,s,a,u
if(r=(new Date).getTime()+1e3,null===e||null===t)throw new Error("Null input. (DiffMain)")
return e===t?e?[[0,e]]:[]:(void 0===n&&(n=!0),i=n,o=this.diffCommonPrefix(e,t),s=e.substring(0,o),e=e.substring(o),t=t.substring(o),o=this.diffCommonSuffix(e,t),a=e.substring(e.length-o),e=e.substring(0,e.length-o),t=t.substring(0,t.length-o),u=this.diffCompute(e,t,i,r),s&&u.unshift([0,s]),a&&u.push([0,a]),this.diffCleanupMerge(u),u)},e.prototype.diffCleanupEfficiency=function(e){var n,r,i,o,s,a,u,l,c
for(n=!1,r=[],i=0,o=null,s=0,a=!1,u=!1,l=!1,c=!1;s<e.length;)0===e[s][0]?(e[s][1].length<4&&(l||c)?(r[i++]=s,a=l,u=c,o=e[s][1]):(i=0,o=null),l=c=!1):(e[s][0]===t?c=!0:l=!0,o&&(a&&u&&l&&c||o.length<2&&a+u+l+c===3)&&(e.splice(r[i-1],0,[t,o]),e[r[i-1]+1][0]=1,i--,o=null,a&&u?(l=c=!0,i=0):(s=--i>0?r[i-1]:-1,l=c=!1),n=!0)),s++
n&&this.diffCleanupMerge(e)},e.prototype.diffPrettyHtml=function(e){var n,r,i,o=[]
for(i=0;i<e.length;i++)switch(n=e[i][0],r=e[i][1],n){case 1:o[i]="<ins>"+Je(r)+"</ins>"
break
case t:o[i]="<del>"+Je(r)+"</del>"
break
case 0:o[i]="<span>"+Je(r)+"</span>"}return o.join("")},e.prototype.diffCommonPrefix=function(e,t){var n,r,i,o
if(!e||!t||e.charAt(0)!==t.charAt(0))return 0
for(i=0,n=r=Math.min(e.length,t.length),o=0;i<n;)e.substring(o,n)===t.substring(o,n)?o=i=n:r=n,n=Math.floor((r-i)/2+i)
return n},e.prototype.diffCommonSuffix=function(e,t){var n,r,i,o
if(!e||!t||e.charAt(e.length-1)!==t.charAt(t.length-1))return 0
for(i=0,n=r=Math.min(e.length,t.length),o=0;i<n;)e.substring(e.length-n,e.length-o)===t.substring(t.length-n,t.length-o)?o=i=n:r=n,n=Math.floor((r-i)/2+i)
return n},e.prototype.diffCompute=function(e,n,r,i){var o,s,a,u,l,c,f,d,h,p,g,m
return e?n?(s=e.length>n.length?e:n,a=e.length>n.length?n:e,-1!==(u=s.indexOf(a))?(o=[[1,s.substring(0,u)],[0,a],[1,s.substring(u+a.length)]],e.length>n.length&&(o[0][0]=o[2][0]=t),o):1===a.length?[[t,e],[1,n]]:(l=this.diffHalfMatch(e,n))?(c=l[0],d=l[1],f=l[2],h=l[3],p=l[4],g=this.DiffMain(c,f,r,i),m=this.DiffMain(d,h,r,i),g.concat([[0,p]],m)):r&&e.length>100&&n.length>100?this.diffLineMode(e,n,i):this.diffBisect(e,n,i)):[[t,e]]:[[1,n]]},e.prototype.diffHalfMatch=function(e,t){var n,r,i,o,s,a,u,l,c,f
if(n=e.length>t.length?e:t,r=e.length>t.length?t:e,n.length<4||2*r.length<n.length)return null
function d(e,t,n){var r,o,s,a,u,l,c,f,d
for(r=e.substring(n,n+Math.floor(e.length/4)),o=-1,s="";-1!==(o=t.indexOf(r,o+1));)a=i.diffCommonPrefix(e.substring(n),t.substring(o)),u=i.diffCommonSuffix(e.substring(0,n),t.substring(0,o)),s.length<u+a&&(s=t.substring(o-u,o)+t.substring(o,o+a),l=e.substring(0,n-u),c=e.substring(n+a),f=t.substring(0,o-u),d=t.substring(o+a))
return 2*s.length>=e.length?[l,c,f,d,s]:null}return i=this,l=d(n,r,Math.ceil(n.length/4)),c=d(n,r,Math.ceil(n.length/2)),l||c?(f=c?l&&l[4].length>c[4].length?l:c:l,e.length>t.length?(o=f[0],u=f[1],a=f[2],s=f[3]):(a=f[0],s=f[1],o=f[2],u=f[3]),[o,u,a,s,f[4]]):null},e.prototype.diffLineMode=function(e,n,r){var i,o,s,a,u,l,c,f,d
for(e=(i=this.diffLinesToChars(e,n)).chars1,n=i.chars2,s=i.lineArray,o=this.DiffMain(e,n,!1,r),this.diffCharsToLines(o,s),this.diffCleanupSemantic(o),o.push([0,""]),a=0,l=0,u=0,f="",c="";a<o.length;){switch(o[a][0]){case 1:u++,c+=o[a][1]
break
case t:l++,f+=o[a][1]
break
case 0:if(l>=1&&u>=1){for(o.splice(a-l-u,l+u),a=a-l-u,d=(i=this.DiffMain(f,c,!1,r)).length-1;d>=0;d--)o.splice(a,0,i[d])
a+=i.length}u=0,l=0,f="",c=""}a++}return o.pop(),o},e.prototype.diffBisect=function(e,n,r){var i,o,s,a,u,l,c,f,d,h,p,g,m,v,b,y,k,w,x,T,E,_,C
for(i=e.length,o=n.length,a=s=Math.ceil((i+o)/2),u=2*s,l=new Array(u),c=new Array(u),f=0;f<u;f++)l[f]=-1,c[f]=-1
for(l[a+1]=0,c[a+1]=0,h=(d=i-o)%2!=0,p=0,g=0,m=0,v=0,E=0;E<s&&!((new Date).getTime()>r);E++){for(_=-E+p;_<=E-g;_+=2){for(y=a+_,x=(k=_===-E||_!==E&&l[y-1]<l[y+1]?l[y+1]:l[y-1]+1)-_;k<i&&x<o&&e.charAt(k)===n.charAt(x);)k++,x++
if(l[y]=k,k>i)g+=2
else if(x>o)p+=2
else if(h&&(b=a+d-_)>=0&&b<u&&-1!==c[b]&&k>=(w=i-c[b]))return this.diffBisectSplit(e,n,k,x,r)}for(C=-E+m;C<=E-v;C+=2){for(b=a+C,T=(w=C===-E||C!==E&&c[b-1]<c[b+1]?c[b+1]:c[b-1]+1)-C;w<i&&T<o&&e.charAt(i-w-1)===n.charAt(o-T-1);)w++,T++
if(c[b]=w,w>i)v+=2
else if(T>o)m+=2
else if(!h&&(y=a+d-C)>=0&&y<u&&-1!==l[y]&&(x=a+(k=l[y])-y,k>=(w=i-w)))return this.diffBisectSplit(e,n,k,x,r)}}return[[t,e],[1,n]]},e.prototype.diffBisectSplit=function(e,t,n,r,i){var o,s,a,u,l,c
return o=e.substring(0,n),a=t.substring(0,r),s=e.substring(n),u=t.substring(r),l=this.DiffMain(o,a,!1,i),c=this.DiffMain(s,u,!1,i),l.concat(c)},e.prototype.diffCleanupSemantic=function(e){var n,r,i,o,s,a,u,l,c,f,d,h,p
for(n=!1,r=[],i=0,o=null,s=0,l=0,c=0,a=0,u=0;s<e.length;)0===e[s][0]?(r[i++]=s,l=a,c=u,a=0,u=0,o=e[s][1]):(1===e[s][0]?a+=e[s][1].length:u+=e[s][1].length,o&&o.length<=Math.max(l,c)&&o.length<=Math.max(a,u)&&(e.splice(r[i-1],0,[t,o]),e[r[i-1]+1][0]=1,i--,s=--i>0?r[i-1]:-1,l=0,c=0,a=0,u=0,o=null,n=!0)),s++
for(n&&this.diffCleanupMerge(e),s=1;s<e.length;)e[s-1][0]===t&&1===e[s][0]&&(f=e[s-1][1],d=e[s][1],(h=this.diffCommonOverlap(f,d))>=(p=this.diffCommonOverlap(d,f))?(h>=f.length/2||h>=d.length/2)&&(e.splice(s,0,[0,d.substring(0,h)]),e[s-1][1]=f.substring(0,f.length-h),e[s+1][1]=d.substring(h),s++):(p>=f.length/2||p>=d.length/2)&&(e.splice(s,0,[0,f.substring(0,p)]),e[s-1][0]=1,e[s-1][1]=d.substring(0,d.length-p),e[s+1][0]=t,e[s+1][1]=f.substring(p),s++),s++),s++},e.prototype.diffCommonOverlap=function(e,t){var n,r,i,o,s,a,u
if(n=e.length,r=t.length,0===n||0===r)return 0
if(n>r?e=e.substring(n-r):n<r&&(t=t.substring(0,n)),i=Math.min(n,r),e===t)return i
for(o=0,s=1;;){if(a=e.substring(i-s),-1===(u=t.indexOf(a)))return o
s+=u,0!==u&&e.substring(i-s)!==t.substring(0,s)||(o=s,s++)}},e.prototype.diffLinesToChars=function(e,t){var r,i
function o(e){var t,o,s,a,u
for(t="",o=0,s=-1,a=r.length;s<e.length-1;)-1===(s=e.indexOf("\n",o))&&(s=e.length-1),u=e.substring(o,s+1),o=s+1,n.call(i,u)?t+=String.fromCharCode(i[u]):(t+=String.fromCharCode(a),i[u]=a,r[a++]=u)
return t}return i={},(r=[])[0]="",{chars1:o(e),chars2:o(t),lineArray:r}},e.prototype.diffCharsToLines=function(e,t){var n,r,i,o
for(n=0;n<e.length;n++){for(r=e[n][1],i=[],o=0;o<r.length;o++)i[o]=t[r.charCodeAt(o)]
e[n][1]=i.join("")}},e.prototype.diffCleanupMerge=function(e){var n,r,i,o,s,a,u,l
for(e.push([0,""]),n=0,r=0,i=0,s="",o="";n<e.length;)switch(e[n][0]){case 1:i++,o+=e[n][1],n++
break
case t:r++,s+=e[n][1],n++
break
case 0:r+i>1?(0!==r&&0!==i&&(0!==(a=this.diffCommonPrefix(o,s))&&(n-r-i>0&&0===e[n-r-i-1][0]?e[n-r-i-1][1]+=o.substring(0,a):(e.splice(0,0,[0,o.substring(0,a)]),n++),o=o.substring(a),s=s.substring(a)),0!==(a=this.diffCommonSuffix(o,s))&&(e[n][1]=o.substring(o.length-a)+e[n][1],o=o.substring(0,o.length-a),s=s.substring(0,s.length-a))),0===r?e.splice(n-i,r+i,[1,o]):0===i?e.splice(n-r,r+i,[t,s]):e.splice(n-r-i,r+i,[t,s],[1,o]),n=n-r-i+(r?1:0)+(i?1:0)+1):0!==n&&0===e[n-1][0]?(e[n-1][1]+=e[n][1],e.splice(n,1)):n++,i=0,r=0,s="",o=""}for(""===e[e.length-1][1]&&e.pop(),u=!1,n=1;n<e.length-1;)0===e[n-1][0]&&0===e[n+1][0]&&((l=e[n][1]).substring(l.length-e[n-1][1].length)===e[n-1][1]?(e[n][1]=e[n-1][1]+e[n][1].substring(0,e[n][1].length-e[n-1][1].length),e[n+1][1]=e[n-1][1]+e[n+1][1],e.splice(n-1,1),u=!0):l.substring(0,e[n+1][1].length)===e[n+1][1]&&(e[n-1][1]+=e[n+1][1],e[n][1]=e[n][1].substring(e[n+1][1].length)+e[n+1][1],e.splice(n+1,1),u=!0)),n++
u&&this.diffCleanupMerge(e)},function(t,n){var r,i
return i=(r=new e).DiffMain(t,n),r.diffCleanupEfficiency(i),r.diffPrettyHtml(i)}}()}()}}])
