package;

import h2d.filter.Filter;
import haxe.ui.styles.Style;
import h2d.filter.Glow;
import haxe.ui.components.Label;
using StringTools;

class LabelOutlined extends Label {

    static var textFilter:Filter;

    public function new() {
        super();

        if ( textFilter == null)
            textFilter = new Glow(0x000000, 1, 4, 2, 1, true);
    }

    override function applyStyle(style:Style) {
        super.applyStyle(style);
        filter = textFilter;
    }

}