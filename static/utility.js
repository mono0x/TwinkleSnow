
Array.prototype.find = function(cond) {
  for(var i = 0, n = this.length; i < n; ++i) {
    if(cond(this[i])) {
      return this[i];
    }
  }
  return null;
};

Array.prototype.empty = function() {
  return this.length == 0;
};

Utility = {};
Utility.openUri = function(uri) {
  var a = document.createElement("a");
  a.href = uri;
  a.target = "_blank";
  a.rel = "noreferrer";
  var e = document.createEvent("MouseEvents");
  e.initMouseEvent(
    "click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 1, null);
  a.dispatchEvent(e);
};

