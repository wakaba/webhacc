function tableToCanvas (table, parent, idPrefix) {
  var canvas = document.createElement ('canvas');
  parent.appendChild (canvas);
  if (window.G_vmlCanvasManager) {
    canvas = G_vmlCanvasManager.initElement (canvas);
  }
  var c2d = canvas.getContext ('2d');

  var param = {
    columnLeft: 20,
    columnWidth: 20,
    columnSpacing: 5,
    columnGroupTop: 10,
    columnTop: 15,
    rowTop: 20,
    rowHeight: 20,
    rowSpacing: 5,
    rowGroupLeft: 10,
    rowGroupFillLeft: 20, /* Must be same as columnLeft */
    rowLeft: 15,
    cellTop: 20,
    cellLeft: 20, /* Must be same as columnLeft */
    cellBottom: 20,
    cellRight: 20,
    explicitColumnGroupStrokeStyle: 'black',
    explicitColumnStrokeStyle: 'black',
    impliedColumnStrokeStyle: '#C0C0C0',
    explicitHeaderRowGroupStrokeStyle: 'black',
    explicitHeaderRowGroupFillStyle: 'rgba(220, 220, 220, 0.3)',
    explicitBodyRowGroupStrokeStyle: 'black',
    explicitBodyRowGroupFillStyle: 'rgba(0, 0, 0, 0)',
    explicitFooterRowGroupStrokeStyle: 'black',
    explicitFooterRowGroupFillStyle: 'rgba(220, 220, 220, 0.3)',
    explicitRowStrokeStyle: 'black',
    impliedRowStrokeStyle: '#C0C0C0',
    headerCellFillStyle: 'rgba(192, 192, 192, 0.5)',
    headerCellStrokeStyle: 'black',
    dataCellFillStyle: 'rgba(0, 0, 0, 0)',
    dataCellStrokeStyle: 'black',
    emptyDataCellStrokeStyle: '#C0C0C0',
    overlappingCellFillStyle: 'red',
    overlappingCellStrokeStyle: 'rgba(0, 0, 0, 0)',
    highlightCellFillStyle: 'yellow'
  };

  canvas.drawTable = function () {

var columnNumber = table.column.length;
if (columnNumber < table.cell.length) columnNumber = table.cell.length;
var rowNumber = 0;
for (var i = 0; i < table.cell.length; i++) {
  if (table.cell[i] && rowNumber < table.cell[i].length) {
    rowNumber = table.cell[i].length;
  }
}

canvas.style.width = 'auto'; // NOTE: Opera9 has default style=""
canvas.style.height = 'auto';
// NOTE: Set style="" before width/height="" for ExplorerCanvas compatibility
canvas.width = param.cellLeft
    + (param.columnWidth + param.columnSpacing) * columnNumber
    + param.cellRight;
canvas.height = param.cellTop
    + (param.rowHeight + param.rowSpacing) * rowNumber
    + param.cellBottom;

var y = param.rowTop;
for (var i = 0; i < table.row_group.length; i++) {
  var rg = table.row_group[i];
  c2d.beginPath ();
  if (rg.type == 'thead') {
    c2d.strokeStyle = param.explicitHeaderRowGroupStrokeStyle;
    c2d.fillStyle = param.explicitHeaderRowGroupFillStyle;
  } else if (rg.type == 'tfoot') {
    c2d.strokeStyle = param.explicitFooterRowGroupStrokeStyle;
    c2d.fillStyle = param.explicitFooterRowGroupFillStyle;
  } else {
    c2d.strokeStyle = param.explicitBodyRowGroupStrokeStyle;
    c2d.fillStyle = param.explicitBodyRowGroupFillStyle;
  }
  var dy = (param.rowHeight + param.rowSpacing) * rg.height;
  c2d.moveTo (param.rowGroupLeft, y);
  c2d.lineTo (param.rowGroupLeft, y + dy - param.rowSpacing);
  c2d.stroke ();
  c2d.closePath ();
  c2d.beginPath ();
  c2d.rect (param.rowGroupFillLeft,
            y,
            (param.columnWidth + param.columnSpacing) * columnNumber - param.columnSpacing,
            dy - param.rowSpacing);
  c2d.fill ();
  c2d.closePath ();
  y += dy;
  i += rg.height - 1;
}

c2d.beginPath ();
c2d.strokeStyle = param.explicitColumnGroupStrokeStyle;
var x = param.columnLeft;
for (var i = 0; i < table.column_group.length; i++) {
  var cg = table.column_group[i];
  c2d.moveTo (x, param.columnGroupTop);
  x += (param.columnWidth + param.columnSpacing) * cg.width;
  c2d.lineTo (x - param.columnSpacing, param.columnGroupTop);
  i += cg.width - 1;
}
c2d.stroke ();
c2d.closePath ();

var x = param.columnLeft;
for (var i = 0; i < columnNumber; i++) {
  var c = table.column[i];
  c2d.beginPath ();
  c2d.moveTo (x, param.columnTop);
  x += param.columnWidth + param.columnSpacing;
  c2d.lineTo (x - param.columnSpacing, param.columnTop);
  if (c) {
    c2d.strokeStyle = param.explicitColumnStrokeStyle;
  } else {
    c2d.strokeStyle = param.impliedColumnStrokeStyle;
  }
  c2d.stroke ();
  c2d.closePath ();
}

var map = document.createElement ('map');
var x = param.cellLeft;
for (var i = 0; i < table.cell.length; i++) {
  var y = param.cellTop;
  if (!table.cell[i]) continue;
  for (var j = 0; j < table.cell[i].length; j++) {
    var c = table.cell[i][j];
    if (c && ((c[0].x == i && c[0].y == j) || c.length > 1)) {
      c2d.beginPath ();
      var width = (param.columnWidth + param.columnSpacing) * c[0].width
          - param.columnSpacing;
      var height = (param.rowHeight + param.rowSpacing) * c[0].height
          - param.rowSpacing;
      if (c.length == 1) {
        c2d.rect (x, y, width, height);
        c2d.fillStyle = c[0].is_header
            ? param.headerCellFillStyle : param.dataCellFillStyle;
        c2d.strokeStyle = c[0].is_header
            ? param.headerCellStrokeStyle
            : c[0].is_empty
                ? param.emptyDataCellStrokeStyle
                : param.dataCellStrokeStyle;
        if (c[0].id) {
          var area = document.createElement ('area');
          area.shape = 'rect';
          area.coords = [x, y, x + width, y + height].join (',');
          area.alt = 'Cell (' + c[0].x + ', ' + c[0].y + ')';
          area.href = '#' + idPrefix + 'node-' + c[0].id;
          area.id = idPrefix + 'cell-' + c[0].id;
          area.onmouseover = (function (v) {
            return function () {
              canvas.highlightCells (v);
            };
          }) (c[0].header);
          map.appendChild (area);
        }
      } else {
        c2d.rect (x, y, param.columnWidth, param.rowHeight);
        c2d.fillStyle = param.overlappingCellFillStyle;
        c2d.strokeStyle = param.overlappingCellStrokeStyle;
      }
      c2d.fill ();
      c2d.stroke ();
      c2d.closePath ();
    }
    y += param.rowHeight + param.rowSpacing;
  }
  x += param.columnWidth + param.columnSpacing;
}

var y = param.rowTop;
for (var i = 0; i < rowNumber; i++) {
  c2d.beginPath ();
  c2d.moveTo (param.rowLeft, y);
  y += param.rowHeight + param.rowSpacing;
  c2d.lineTo (param.rowLeft, y - param.rowSpacing);
  //if (true) {
    c2d.strokeStyle = param.explicitRowStrokeStyle;
  //} else {
  //  c2d.strokeStyle = param.impliedRowStrokeStyle;
  //}
  c2d.stroke ();
  c2d.closePath ();
}

    return map;
  }; // canvas.drawTable

  canvas.highlightCells = function (cells) {
    var c2d = this.getContext ('2d');

    for (var x in cells) {
      for (var y in cells[x]) {
        if (cells[x][y]) {
          var cell = table.cell[x][y][0];
          c2d.beginPath ();
          c2d.rect
              (param.cellLeft + (param.columnWidth + param.columnSpacing) * x,
               param.cellTop + (param.rowHeight + param.rowSpacing) * y,
               (param.columnWidth + param.columnSpacing) * cell.width - param.columnSpacing,
               (param.rowHeight + param.rowSpacing) * cell.height - param.rowSpacing);
          c2d.fillStyle = param.highlightCellFillStyle;
          c2d.fill ();
          c2d.stroke ();
          c2d.closePath ();
        }
      }
    }
    this.updateImgElement ();
  } // canvas.highlightCells

  var map = canvas.drawTable ();
  if (map.hasChildNodes ()) {
    var mapid = /* idPrefix + */ 'table-map-' + ++document.TableMapId;
    map.name = mapid;
    parent.appendChild (map);
    var img = document.createElement ('img');
    img.useMap = '#' + mapid;
    canvas.updateImgElement = function () {
      img.src = this.toDataURL ();
    };
    img.onmouseover = function (e) {
      if (e.target == e.currentTarget) {
        canvas.drawTable ();
        canvas.updateImgElement ();
      }
    };
    canvas.updateImgElement ();
    parent.appendChild (img);
    canvas.style.display = 'none';
  } else {
    canvas.updateImgElement = function () {};
  }
} // tableToCanvas

if (!document.TableMapId) document.TableMapId = 0;

/*

Copyright 2007-2008 Wakaba <w@suika.fam.cx>

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

*/
/* $Date: 2008/05/06 08:47:09 $ */
