package;

import haxe.ui.events.MouseEvent;
import haxe.ui.containers.dialogs.Dialog;

using StringTools;

@:build(haxe.ui.macros.ComponentMacros.build("assets/text-dialog.xml"))
class TextDialog extends Dialog {

    public var defaultValue = "";

    public function new() {
        super();
        title = "Text Dialog";
        closable = false;
        buttons = DialogButton.CANCEL | DialogButton.SAVE;
    }

    @:bind( resetButton, MouseEvent.CLICK)
    public function resetToDefault(e) {
        rename.text = defaultValue;
    }

    /** get value of the text field, sanitized and cleaned up **/
    public function getDialogValue() {
        return rename.text.trim().replace('\"', ' ').replace('"', ' ').replace('\n', ' ').replace('\r', ' ').replace('\\', ' ');
    }
}