package ;

import haxe.ui.components.Button;
import haxe.ui.containers.HBox;
import haxe.ui.components.Label;
import Database.MapEntry;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;

using DateTools;

@:build(haxe.ui.ComponentBuilder.build("assets/map-list.xml"))
class MapList extends VBox {
    public var mapListName:String = "NEW LIST";

    public function new() {
        super();
    }

    public override function onInitialize() {
        super.onInitialize();
        findComponent("listName", Label).text = mapListName;
    }

    public function addMapButton(mapData:MapEntry) {
        var listContents = findComponent("listContents", HBox);
        var newButton = new MapButton();
        newButton.mapData = mapData;
        listContents.addComponent(newButton);
    }

    // private var _fadeTimer:Timer = null;
    // @:access(haxe.ui.core.Component)
    // private function onMouseWheel(event:MouseEvent) {
    //     var vscroll:VerticalScroll = _scrollview.findComponent(VerticalScroll, false);
    //     if (vscroll != null) {
    //         var builder = cast(_scrollview._compositeBuilder, ScrollViewBuilder);
    //         if (builder.autoHideScrolls == true && _fadeTimer == null) {
    //             vscroll.fadeIn();
    //         }
    //         event.cancel();
    //         var amount = 50; // TODO: calculate this
    //         #if haxeui_pdcurses
    //         amount = 2;
    //         #end
    //         if (event.delta > 0) {
    //             vscroll.pos -= amount;
    //         } else if (event.delta < 0) {
    //             vscroll.pos += amount;
    //         }
    //         if (builder.autoHideScrolls == true) {
    //             if (_fadeTimer != null) {
    //                 _fadeTimer.stop();
    //                 _fadeTimer = null;
    //             }
    //             _fadeTimer = new Timer(300, function() {
    //                 vscroll.fadeOut();
    //                 _fadeTimer.stop();
    //                 _fadeTimer = null;
    //             });
    //         }
    //     }
    // }

}