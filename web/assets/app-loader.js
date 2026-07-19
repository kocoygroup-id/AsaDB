/* Copyright (C) 2026 Kocoy Group and AsaDB contributors */
/* SPDX-License-Identifier: GPL-3.0-only */
/*
 * Browser-safe entry point for AsAPanel.
 *
 * app.js is the readable source. app.legacy.js is the checked-in build that
 * avoids syntax unsupported by older Firefox builds commonly used on minimal
 * Linux systems. Keep this file ES5-compatible: it runs before the bundle.
 */
(function () {
  'use strict';

  var doc = document;
  var bootErrorShown = false;

  function addClass(element, className) {
    if (!element) return;
    if (element.classList) {
      element.classList.add(className);
      return;
    }
    if ((' ' + element.className + ' ').indexOf(' ' + className + ' ') === -1) {
      element.className += (element.className ? ' ' : '') + className;
    }
  }

  function showBootError() {
    var host;
    var notice;
    var title;
    var copy;
    if (bootErrorShown || window.__asadbUiReady) return;
    bootErrorShown = true;
    addClass(doc.getElementById('startupLoader'), 'hidden');

    host = doc.body || doc.documentElement;
    if (!host || doc.getElementById('uiBootError')) return;
    notice = doc.createElement('div');
    notice.id = 'uiBootError';
    notice.className = 'ui-boot-error';
    notice.setAttribute('role', 'alert');
    title = doc.createElement('strong');
    title.appendChild(doc.createTextNode('AsAPanel gagal memuat antarmuka.'));
    copy = doc.createElement('span');
    copy.appendChild(doc.createTextNode('Tekan Ctrl+Shift+R. Jika masih muncul, buka Console Firefox (Ctrl+Shift+K) lalu kirim teks merahnya.'));
    notice.appendChild(title);
    notice.appendChild(copy);
    host.appendChild(notice);
  }

  function installCompatibilityPolyfills() {
    function installForEach(prototype) {
      if (!prototype || prototype.forEach) return;
      prototype.forEach = function (callback, thisArg) {
        var i;
        for (i = 0; i < this.length; i += 1) {
          callback.call(thisArg, this[i], i, this);
        }
      };
    }

    installForEach(window.NodeList && window.NodeList.prototype);
    installForEach(window.HTMLCollection && window.HTMLCollection.prototype);

    if (!Object.values) {
      Object.values = function (object) {
        var keys = Object.keys(object);
        var values = [];
        var i;
        for (i = 0; i < keys.length; i += 1) values.push(object[keys[i]]);
        return values;
      };
    }
    if (!Object.entries) {
      Object.entries = function (object) {
        var keys = Object.keys(object);
        var entries = [];
        var i;
        for (i = 0; i < keys.length; i += 1) entries.push([keys[i], object[keys[i]]]);
        return entries;
      };
    }
    if (!Array.from) {
      Array.from = function (value) {
        return Array.prototype.slice.call(value);
      };
    }
    if (!Array.prototype.includes) {
      Array.prototype.includes = function (value, fromIndex) {
        var start = Number(fromIndex) || 0;
        var i;
        if (start < 0) start = Math.max(this.length + start, 0);
        for (i = start; i < this.length; i += 1) {
          if (this[i] === value || (this[i] !== this[i] && value !== value)) return true;
        }
        return false;
      };
    }
    if (!String.prototype.includes) {
      String.prototype.includes = function (value, fromIndex) {
        return this.indexOf(value, fromIndex || 0) !== -1;
      };
    }
    if (!String.prototype.startsWith) {
      String.prototype.startsWith = function (value, fromIndex) {
        var start = fromIndex || 0;
        return this.slice(start, start + String(value).length) === String(value);
      };
    }
    if (!String.prototype.endsWith) {
      String.prototype.endsWith = function (value, endPosition) {
        var end = endPosition === undefined ? this.length : Number(endPosition);
        var text = String(value);
        return this.slice(end - text.length, end) === text;
      };
    }
    if (!String.prototype.padStart) {
      String.prototype.padStart = function (targetLength, fillString) {
        var text = String(this);
        var fill = fillString === undefined ? ' ' : String(fillString);
        while (text.length < targetLength) text = fill + text;
        return text.slice(text.length - targetLength);
      };
    }
    if (!Number.isFinite) {
      Number.isFinite = function (value) {
        return typeof value === 'number' && isFinite(value);
      };
    }

    if (window.Element && window.Element.prototype) {
      var elementPrototype = window.Element.prototype;
      if (!elementPrototype.matches) {
        elementPrototype.matches = elementPrototype.msMatchesSelector || elementPrototype.webkitMatchesSelector;
      }
      if (!elementPrototype.closest) {
        elementPrototype.closest = function (selector) {
          var node = this;
          while (node && node.nodeType === 1) {
            if (node.matches && node.matches(selector)) return node;
            node = node.parentElement;
          }
          return null;
        };
      }
      if (!elementPrototype.append) {
        elementPrototype.append = function () {
          var fragment = doc.createDocumentFragment();
          var i;
          var item;
          for (i = 0; i < arguments.length; i += 1) {
            item = arguments[i];
            fragment.appendChild(item && item.nodeType ? item : doc.createTextNode(String(item)));
          }
          this.appendChild(fragment);
        };
      }
      if (!elementPrototype.remove) {
        elementPrototype.remove = function () {
          if (this.parentNode) this.parentNode.removeChild(this);
        };
      }
    }
  }

  function loadPanelBundle() {
    var script = doc.createElement('script');
    script.type = 'text/javascript';
    script.async = false;
    script.src = 'assets/app.legacy.js';
    script.onerror = showBootError;
    script.onload = function () {
      window.setTimeout(showBootError, 0);
    };
    (doc.head || doc.getElementsByTagName('head')[0] || doc.documentElement).appendChild(script);
  }

  installCompatibilityPolyfills();
  loadPanelBundle();
  window.setTimeout(showBootError, 3000);
}());
