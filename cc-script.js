function addSourceToParseErrorList (idPrefix) {
  var parseErrorsList = document.getElementById
      (idPrefix + 'parse-errors-list');
  if (!parseErrorsList) return;
  var childs = parseErrorsList.childNodes;
  var childsL = childs.length;
  var line = 0;
  var column = 0;
  for (var i = 0; i < childsL; i++) {
    var child = childs[i];
    if (child.nodeType != 1) continue;
    if (child.nodeName == 'DT') {
      var text = child.textContent || child.innerText;
      var m;
      if (m = text.match (/Line (\d+)(?: column (\d+))?/)) {
        line = parseInt (m[1]);
        column = parseInt (m[2] || 0);
      } else {
        line = 0;
        column = 0;
      }
    } else if (child.nodeName == 'DD') {
      if (line > 0) {
        var lineEl = document.getElementById (idPrefix + 'line-' + line);
        if (lineEl) {
          lineText = lineEl.innerHTML
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

// $Date: 2008/03/16 05:45:10 $
