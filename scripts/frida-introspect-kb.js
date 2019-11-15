var UIWindow = ObjC.classes.UIWindow

var allwindows = UIWindow.allWindowsIncludingInternalWindows_onlyVisibleWindows_(true, true)
var rkbw = allwindows.objectAtIndex_(2)
var it = rkbw.subviews().objectAtIndex_(0)
var it = it.subviews().objectAtIndex_(0)
var UIKBCompatInputView = it.subviews().objectAtIndex_(2)
var UIKeyboardAutomatic = UIKBCompatInputView.subviews().objectAtIndex_(0)
var UIKeyboardImpl = UIKeyboardAutomatic.subviews().objectAtIndex_(0)
var UIKeyboardLayoutStar = UIKeyboardImpl.subviews().objectAtIndex_(0)
var UIKBKeyplaneView = UIKeyboardLayoutStar.subviews().objectAtIndex_(0)

var keyplane = UIKBKeyplaneView.keyplane()
var r_key = keyplane.subtrees().objectAtIndex_(0).keySet().subtrees().objectAtIndex_(0).subtrees().objectAtIndex_(3)

var sdkl = keyplane.subtrees().objectAtIndex_(1)
var shiftdeletes = sdkl.keySet().subtrees().objectAtIndex_(0).subtrees()
var shiftk = shiftdeletes.objectAtIndex_(0)
var deletek = shiftdeletes.objectAtIndex_(1)

var controlkl = keyplane.subtrees().objectAtIndex_(2)
var controlkeys = controlkl.keySet().subtrees().objectAtIndex_(0).subtrees()
var morek = controlkeys.objectAtIndex_(0)
var internationalk = controlkeys.objectAtIndex_(1)
var dictationk = controlkeys.objectAtIndex_(2)
var spacek = controlkeys.objectAtIndex_(3)
var returnk = controlkeys.objectAtIndex_(4)
