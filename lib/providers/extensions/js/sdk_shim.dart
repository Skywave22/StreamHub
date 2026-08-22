/// The JavaScript SDK surface injected into the QuickJS runtime before an
/// extension script is evaluated. Implements the SkyStream/CloudStream
/// extension API: `app.get/post/head`, `parseHtml` (DOM bridging to Dart),
/// `MultimediaItem`/`StreamResult`/`Episode`, preferences, storage, captcha
/// and crypto stubs. Extensions export their entry points to `globalThis`
/// (`getHome`, `search`, `load`, `loadStreams`).
abstract final class SdkShim {
  static String source({required String manifestJson}) {
    const shim = r'''
// ===== StreamHub extension SDK =====
var __sh = {
  call: function (method, params) {
    var res = sendMessage('streamhub', JSON.stringify({ method: method, params: params || {} }));
    if (typeof res === 'string') { try { res = JSON.parse(res); } catch (e) { res = null; } }
    return res;
  }
};

function __shReq(method, url, referer, extra) {
  var headers = {};
  if (referer) headers['Referer'] = referer;
  if (extra && extra.headers) { for (var k in extra.headers) headers[k] = extra.headers[k]; }
  return fetch(url, { method: method, headers: headers, body: extra && extra.body ? extra.body : undefined })
    .then(function (r) {
      return r.text().then(function (t) {
        var h = {};
        try { if (r.headers && r.headers.entries) { r.headers.entries().forEach(function (e) { h[String(e[0]).toLowerCase()] = e[1]; }); } } catch (e) {}
        return {
          text: t, body: t, html: t,
          status: r.status, statusCode: r.status,
          url: r.url || url, finalUrl: r.url || url,
          headers: h, cookies: '',
          document: parseHtml(t),
          select: function (sel) { return parseHtml(t).querySelectorAll(sel); },
          selectFirst: function (sel) { return parseHtml(t).querySelector(sel); }
        };
      });
    });
}

var app = {
  get: function (url, referer, extra) { return __shReq('GET', url, referer, extra); },
  post: function (url, body, referer, extra) {
    var e = Object.assign({}, extra || {}); e.body = body;
    return __shReq('POST', url, referer, e);
  },
  head: function (url, referer, extra) { return __shReq('HEAD', url, referer, extra); },
  quickRequest: function (url, referer) { return __shReq('GET', url, referer, null); },
  getStream: function (url, referer) { return __shReq('GET', url, referer, null); },
  parseHtml: function (html) { return parseHtml(html); },
  jsEval: function (code) { try { return eval(code); } catch (e) { return null; } },
  getPreference: function (key) { return getPreference(key); },
  setPreference: function (key, value) { return setPreference(key, value); }
};

// ===== entities =====
class MultimediaItem {
  constructor(p) { Object.assign(this, { type: 'movie', status: 'ongoing', streams: [], syncData: {}, playbackPolicy: 'none', isAdult: false }, p); }
}
class Episode {
  constructor(p) { Object.assign(this, { season: 0, episode: 0, streams: [], playbackPolicy: 'none' }, p); }
}
class StreamResult {
  constructor(p) {
    p = p || {};
    this.url = p.url; this.source = p.source || 'Auto'; this.headers = p.headers;
    this.subtitles = p.subtitles; this.drmKid = p.drmKid; this.drmKey = p.drmKey; this.licenseUrl = p.licenseUrl;
  }
}
class Actor { constructor(p) { Object.assign(this, p); } }
class Trailer { constructor(p) { Object.assign(this, p); } }
class NextAiring { constructor(p) { Object.assign(this, p); } }
globalThis.MultimediaItem = MultimediaItem;
globalThis.Episode = Episode;
globalThis.StreamResult = StreamResult;
globalThis.Actor = Actor;
globalThis.Trailer = Trailer;
globalThis.NextAiring = NextAiring;

var CloudStream = { getLanguage: function () { return 'en'; }, getRegion: function () { return 'US'; } };
globalThis.CloudStream = CloudStream;

async function solveCaptcha(siteKey, url) { return __sh.call('solve_captcha', { siteKey: siteKey, url: url || '' }); }
globalThis.solveCaptcha = solveCaptcha;

globalThis.crypto = {
  decryptAES: function (data, key, iv, options) { throw new Error('crypto.decryptAES is not supported in StreamHub'); },
  pbkdf2: function (password, salt, iterations, keyLength) { throw new Error('crypto.pbkdf2 is not supported in StreamHub'); }
};

// ===== preferences / storage (bridged to Dart) =====
function getPreference(key) { return __sh.call('get_preference', { key: key }); }
function setPreference(key, value) { return __sh.call('set_preference', { key: key, value: value }); }
globalThis.getPreference = getPreference;
globalThis.setPreference = setPreference;

// ===== DOM (parsed in Dart, queried via bridge) =====
function __q(query, nodeId, multi) {
  var res = __sh.call('dom_query', { nodeId: nodeId, query: query, multi: !!multi });
  return res;
}
function JSNode(id, data) {
  this.nodeId = id; this.data = data || {};
  this.textContent = this.data.textContent || '';
  this.innerHTML = this.data.innerHTML || '';
  this.outerHTML = this.data.outerHTML || '';
  this.tagName = this.data.tagName || '';
}
JSNode.prototype.getAttribute = function (n) { return this.data.attributes ? this.data.attributes[n] : null; };
JSNode.prototype.attr = function (n) { return this.getAttribute(n); };
JSNode.prototype.text = function () { return this.textContent; };
JSNode.prototype.html = function () { return this.innerHTML; };
JSNode.prototype.outerHtml = function () { return this.outerHTML; };
JSNode.prototype.querySelector = function (q) { var r = __q(q, this.nodeId, false); return r ? new JSNode(r.nodeId, r) : null; };
JSNode.prototype.querySelectorAll = function (q) { var r = __q(q, this.nodeId, true); return (r || []).map(function (d) { return new JSNode(d.nodeId, d); }); };
JSNode.prototype.select = function (q) { return this.querySelectorAll(q); };
JSNode.prototype.selectFirst = function (q) { return this.querySelector(q); };
Object.defineProperty(JSNode.prototype, 'className', { get: function () { return this.getAttribute('class') || ''; } });
Object.defineProperty(JSNode.prototype, 'children', {
  get: function () {
    var r = __q('*', this.nodeId, true);
    var self = this;
    return (r || []).filter(function (d) { return d.nodeId !== self.nodeId; }).map(function (d) { return new JSNode(d.nodeId, d); });
  }
});
function JSDocument(id) { JSNode.call(this, id, { nodeId: id }); }
JSDocument.prototype = Object.create(JSNode.prototype);
Object.defineProperty(JSDocument.prototype, 'body', { get: function () { return this.querySelector('body') || this; } });
function parseHtml(html) {
  var id = __sh.call('dom_parse', { html: String(html == null ? '' : html) });
  return new JSDocument(id);
}
globalThis.parseHtml = parseHtml;
globalThis.JSDOM = function (html) { return { window: { document: parseHtml(html) } }; };

// ===== manifest =====
var manifest = JSON.parse('__MANIFEST_JSON__');
globalThis.manifest = manifest;
''';
    return shim.replaceFirst('__MANIFEST_JSON__', _jsEscape(manifestJson));
  }

  static String _jsEscape(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n').replaceAll('\r', '');
}
