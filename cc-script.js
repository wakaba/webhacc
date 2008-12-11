function addSourceToParseErrorList (idPrefix, dlId) {
  var parseErrorsList = document.getElementById
      (idPrefix + dlId);
  if (!parseErrorsList) return;
  var childs = parseErrorsList.childNodes;
  var childsL = childs.length;
  var line = 0;
  var column = 0;
  for (var i = 0; i < childsL; i++) {
    var child = childs[i];
    if (child.nodeType != 1) continue;
    if (child.nodeName == 'DT') {
      line = parseInt (child.getAttribute ('data-line') || 0);
      column = parseInt (child.getAttribute ('data-column') || 0);
    } else if (child.nodeName == 'DD') {
      if (line > 0) {
        var lineEl = document.getElementById (idPrefix + 'line-' + line);
        if (lineEl) {
          lineText = lineEl.innerHTML
              .replace (/<var>U\+([0-9A-F]{4})<\/var>/g, function (s) {
                return String.fromCharCode (parseInt (s, 16));
              })
              .replace (/&lt;/g, '<')
              .replace (/&gt;/g, '>')
              .replace (/&nbsp;/g, '\u00A0')
              .replace (/&quot;/g, '"')
              .replace (/&amp;/g, '&');
          var p = document.createElement ('p');
          p.className = 'source-fragment';
          var code = document.createElement ('code');
          if (lineText.length > 50) {
            if (column - 25 > 0) {
              p.appendChild (document.createElement ('var')).innerHTML
                  = '...';
              lineText = lineText.substring (column - 25, column + 24);
              code.appendChild (document.createTextNode
                  (lineText.substring (0, 24)));
              code.appendChild (document.createElement ('mark'))
                  .appendChild (document.createTextNode
                      (lineText.charAt (24)));
              code.appendChild (document.createTextNode
                  (lineText.substring (25, lineText.length)));
              p.appendChild (code);
              p.appendChild (document.createElement ('var')).innerHTML
                  = '...';
            } else {
              lineText = lineText.substring (0, 50);
              if (column > 0) {
                code.appendChild (document.createTextNode
                    (lineText.substring (0, column - 1)));
                code.appendChild (document.createElement ('mark'))
                    .appendChild (document.createTextNode
                        (lineText.charAt (column - 1)));
                code.appendChild (document.createTextNode
                    (lineText.substring (column, lineText.length)));
              } else {
                code.appendChild (document.createTextNode
                    (lineText.substring (0, 50)));
              }
              p.appendChild (code);
              p.appendChild (document.createElement ('var')).innerHTML
                  = '...';
            }
          } else {
            if (column > 0) {
              code.appendChild (document.createTextNode
                  (lineText.substring (0, column - 1)));
              code.appendChild (document.createElement ('mark'))
                  .appendChild (document.createTextNode
                      (lineText.charAt (column - 1)));
              code.appendChild (document.createTextNode
                  (lineText.substring (column, lineText.length)));
            } else {
              code.appendChild (document.createTextNode (lineText));
            }
            p.appendChild (code);
          }
          child.appendChild (p);
        }
      }
      line = 0;
      column = 0;
    }
  }
} // addSourceToParseErrorList

function insertNavSections (parentId) {
  parentId = parentId || '';
  var el = document.createElement ('nav');
  el.id = parentId + 'nav-sections';
  el.innerHTML = '<ul></ul>';
  
  if (parentId == '') {
    document.body.appendChild (el);
    document.webhaccSections = {};
    document.body.setAttribute ('data-scripted', '');
  } else {
    var section = document.getElementById (parentId);
    section.appendChild (el);
    section.webhaccSections = {};
  }
} // insertNavSections

function addSectionLink (id, label, parentId) {
  parentId = parentId || '';

  var el = document.createElement ('li');
  el.innerHTML = '<a></a>';
  el.firstChild.href = '#' + id;
  el.firstChild.innerHTML = label;
  document.getElementById (parentId + 'nav-sections')
      .firstChild.appendChild (el);

  var sections = document.webhaccSections;
  if (parentId != '') {
    sections = document.getElementById (parentId).webhaccSections;
  }
  sections[id] = document.getElementById (id);
  sections[id].tabElement = el;

  if (id == 'input' || id == 'input-url') {
    showTab (id);
    document.webhaccNavigated = false;
  } else if (id == 'document-info' && !document.webhaccNavigated) {
    showTab (id);
    document.webhaccNavigated = false;
  } else if (id.match (/-document-info$/)) {
    sections[id].tabElement.setAttribute ('data-active', '');
  } else {
    sections[id].style.display = 'none';
  }
} // addSectionLink

function showTab (id) {
  var ids = [];
  if (id.match (/^line-/)) {
    ids = ['source-string'];
  } else if (id.match (/^node-/)) {
    ids = ['document-tree'];
  } else if (id.match (/^index-/)) {
    ids = ['document-structure'];
  } else if (id.match (/^subdoc-[^-]+-/)) {
    var m;
    ids = [''];
    while (true) {
      if (m = id.match (/^subdoc-[^-]+-/)) {
        ids.push (ids[ids.length - 1] + m[0]);
        id = id.substring (m[0].length);
      } else {
        break;
      }
    }
    if (id.length > 0) {
      if (id.match (/^line-/)) {
        ids.push (ids[ids.length - 1] + 'source-string');
      } else if (id.match (/^node-/)) {
        ids.push (ids[ids.length - 1] + 'document-tree');
      } else if (id.match (/^index-/)) {
        ids.push (ids[ids.length - 1] + 'document-structure');
      } else {
        ids.push (ids[ids.length - 1] + id);
      }
    }
    ids.shift (); // ''
  } else if (id.match (/^input-/)) {
    ids = ['input', id];
  } else {
    ids = [id];
  }

  var sections = document.webhaccSections;
  while (ids.length > 0) {
    var myid = ids.shift ();
    _showTab (sections, myid);
    sections = sections[myid].webhaccSections;
    if (!sections) break;
  }
} // showTab

function _showTab (sections, id) {
  if (sections[id]) {
    for (var i in sections) {
      sections[i].style.display = 'none';
      sections[i].tabElement.removeAttribute ('data-active');
    }
    sections[id].style.display = 'block';
    sections[id].tabElement.setAttribute ('data-active', '');
    sections[id].tabElement.scrollIntoView ();

    document.webhaccNavigated = true;
  }
} // _showTab

function getAncestorElements (e) {
  var ret = {};
  do {
    if (e.nodeName == 'A' || e.nodeName == 'AREA') {
      ret.a = e;
      if (ret.aside) {
        return ret;
      }
    } else if (e.nodeName == 'ASIDE' || e.nodeName == 'aside') {
      ret.aside = e;
      if (ret.a) {
        ret.aInAside = true;
        return ret;
      }
    }
    e = e.parentNode;
  } while (e);
  return ret;
} // getAncestorElements

function showHelp (id, context) {
  if (document.webhaccHelp === undefined) {
    loadHelp ('../error-description', function () {
      _showHelp (id, context);
    });
    return true;
  } else if (document.webhaccHelp === null) {
    return false;
  } else {
    _showHelp (id, context);
  }
} // showHelp

function loadHelp (url, code) {
  document.webhaccHelp = null;
  var iframe = document.createElement ('iframe');
  iframe.className = 'ajax';
  var iframecode = function () {
    var doc;
    var docel;
    try {
      doc = iframe.contentWindow.document;
      docel = doc.getElementById ('error-description');
    } catch (e) { }
    if (docel) {
      document.webhaccHelp = doc;
      code ();
    } else if (url != '../error-description.en.html.u8') {
      // doc would be a 406 error.
      loadHelp ('../error-description.en.html.u8', code);
      iframe.parentNode.removeChild (iframe);
      /*
        |iframe| is removed from the document after another |iframe|
        is inserted by nested |loadHelp| call, otherwise Safari 3
        would reuse(?) removed |iframe| and it sometimes (not always)
        requests old URL even when another URL is set to the |src| attribute.
      */
    }
    iframe.onreadystatechange = null;
    iframe.onload = null;
  };
  iframe.onreadystatechange = function () {
    if (this.readyState == 'complete') {
      iframecode ();
    }
  };
  iframe.onload = iframecode;
  iframe.src = url;
  document.body.appendChild (iframe);
} // loadHelp

function _showHelp (id, context) {
  var helpDataEl = document.webhaccHelp.getElementById (id);
  if (!helpDataEl) {
    helpDataEl = document.webhaccHelp.getElementById ('help-not-available');
    if (!helpDataEl) {
      helpDataEl = document.createElement ('div');
      helpDataEl.innerHTML = '<p>There is no help for this item available.';
    }
  }

  if (id != 'help-not-available' &&
      helpDataEl.getElementsByTagName ('p').length == 0) {
    _showHelp ('help-not-available', context);
    return;
  }

  var helpBox = document.createElement ('aside');
  helpBox.className = 'help';
  helpBox.innerHTML = helpDataEl.innerHTML; /* adoptNode + appendChild */
  document.body.appendChild (helpBox);

  var vp = document.documentElement;
  if (vp.clientHeight < document.body.clientHeight) {
    vp = document.body;
    /*
      |vp| is the element that is associated with the viewport.
      In standard mode, the viewport element is the root element, i.e.
      the |document.documentElement|.  However, in Opera 9, the viewport
      element is the |body| element.  If the document element is not the
      viewport element, its |clientHeight| takes less value than that
      of the |body| element.  (I don't know whether this is always true.)
    */
  }


  var left = context.x;
  var top = context.y;
  if (left > vp.clientWidth * 0.5) {
    helpBox.style.left = '45%';
  } else if (left < 10) {
    helpBox.style.left = '10px';
  } else {
    helpBox.style.left = left + 'px';
  }
  if (top > vp.clientHeight - 100) {
    helpBox.style.bottom = '10px';
  } else if (top < 10) {
    helpBox.style.top = '10px';
  } else {
    helpBox.style.top = top + 'px';
  }

  if (helpBox.offsetTop + helpBox.clientHeight > vp.clientHeight) {
    helpBox.style.top = '50%';
    helpBox.style.bottom = '10px';
  }
} // _showHelp

function removeHelps () {
  var asides = document.getElementsByTagName ('aside');
  while (asides.length > 0) {
    var aside = asides[0];
    aside.parentNode.removeChild (aside);
  }
} // removeHelps

function onbodyclick (ev) {
  var aels = getAncestorElements (ev.target || ev.srcElement);

  if (!aels.aside) {
    removeHelps ();
  }

  if (aels.a) {
    var href = aels.a.getAttribute ('href');
    if (href) {
      var m;
      if (href.match (/^#/)) {
        var id = decodeURIComponent (href.substring (1));
        showTab (id);
        return true;
      } else if ((aels.a.rel == 'help' /* relList.has ('help') */) &&
                 (m = href.match (/#(.+)$/) /* aels.a.hash, in fact... */)) {
        var id = decodeURIComponent (m[1]);
        showHelp (id, {x: ev.clientX, y: ev.clientY});
        return false;
      } else if (href.match (/^.\/#/)) {
        var id = decodeURIComponent (href.substring (3));
        showTab (id);
        if (aels.aInAside) {
          removeHelps ();
        }
        return true;
      }
    }
  }

  return true;
} // onbodyclick

function onbodyload () {
  // This block should be executed at the end of initialization process,
  // since |decodeURIComponent| might throw.
  if (!document.webhaccNavigated) {
    var fragment = location.hash;
    if (fragment) {
      var id = decodeURIComponent (fragment.substring (1));
      showTab (id);
      var el = document.getElementById (id);
      if (el) el.scrollIntoView ();
    } else if (document.webhaccSections['result-summary']) {
      showTab ('result-summary');
    } else {
      showTab ('input');
    }
  }
} // onbodyload

// $Date: 2008/12/11 05:11:11 $
