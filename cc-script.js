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

function insertNavSections () {
  var el = document.createElement ('nav');
  el.id = 'nav-sections';
  el.innerHTML = '<ul></ul>';
  document.body.appendChild (el);
  document.webhaccSections = {};
  document.body.setAttribute ('data-scripted', '');
} // insertNavSections

function addSectionLink (id, label) {
  var el = document.createElement ('li');
  el.innerHTML = '<a></a>';
  el.firstChild.href = '#' + id;
  el.firstChild.innerHTML = label;
  document.getElementById ('nav-sections').firstChild.appendChild (el);
  document.webhaccSections[id] = document.getElementById (id);
  document.webhaccSections[id].tabElement = el;
  if (id == 'input') {
    //
  } else if (id == 'document-info' && !document.webhaccNavigated) {
    showTab ('document-info');
    document.webhaccNavigated = false;
  } else {
    document.webhaccSections[id].style.display = 'none';
  }
} // addSectionLink

function showTab (id) {
  var m;
  if (id.match (/^line-/)) {
    id = 'source-string';
  } else if (id.match (/^node-/)) {
    id = 'document-tree';
  } else if (m = id.match (/^(subdoc-\d+-)/)) {
    id = m[1];
  }

  if (document.webhaccSections[id]) {
    for (var i in document.webhaccSections) {
      document.webhaccSections[i].style.display = 'none';
      document.webhaccSections[i].tabElement.removeAttribute ('data-active');
    }
    document.webhaccSections[id].style.display = 'block';
    document.webhaccSections[id].tabElement.setAttribute ('data-active', '');

    document.webhaccNavigated = true;
  }

} // showTab

function getAncestorAnchorElement (e) {
  do {
    if (e.nodeName == 'A') {
      return e;
    }
    e = e.parentNode;
  } while (e);
} // getAncestorAnchorElement

function onbodyclick (ev) {
  var a = getAncestorAnchorElement (ev.target || ev.srcElement);
  if (a) {
    var href = a.getAttribute ('href');
    if (href && href.match (/^#/)) {
      var id = decodeURIComponent (href.substring (1));
      showTab (id);
      return true;
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
    } else if (document.webhaccSections['result-summary']) {
      showTab ('result-summary');
    } else {
      showTab ('input');
    }
  }
} // onbodyload

// $Date: 2008/08/10 11:49:43 $
