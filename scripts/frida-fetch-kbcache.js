var kbcache = null;

var NSCache = ObjC.classes.NSCache;
var scl = NSCache['- setCountLimit:'];
var oldSCL = scl.implementation;
scl.implementation = ObjC.implement(scl,
	function(handle, selector, z) {
		console.log(handle, z);
		if (z == 50) {
			console.log('found kbcache');
			kbcache = new ObjC.Object(handle);
		}
		oldSCL(handle, selector, z);
	});

var _img2png = new NativeFunction(Module.findExportByName(null, 'UIImagePNGRepresentation'), 'pointer', ['pointer']);
function img2png(img) {
	return new ObjC.Object(_img2png(img));
}

var nsfm = ObjC.classes.NSFileManager.defaultManager();
var path = nsfm.temporaryDirectory().toString().replace('file://', '');

function img2pngFile(img, name) {
	var png = img2png(img);
	console.log('writing ' + path + name);
	var result = png.writeToFile_atomically_(path + name, false);
	if (result)
		console.log('ok');
	else
		console.log('failed');
}


function dumpAll() {
	var array = kbcache.allObjects();
	for (var i = 0; i < array.count(); i++) {
		var img = array.objectAtIndex_(i);
		img2pngFile(img, 'kb' + i + '.png');
	}
}
