package ;

import haxe.ui.styles.animation.util.Actuator;
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
    var mapButtons:Array<MapButton> = new Array<MapButton>();
    // public var listContents:HBox;

    public function new() {
        super();
    }

    public override function onInitialize() {
        super.onInitialize();
        listContents = findComponent("listContents", HBox);
        findComponent("listName", Label).text = mapListName;
    }

    public function addMapButton(mapData:MapEntry) {
        var newButton = new MapButton();
        newButton.mapData = mapData;
        listContents.addComponent(newButton);
        mapButtons.push(newButton);
    }

    public function refreshMapButtons() {
        for( mapButton in mapButtons) {
            mapButton.refreshMapButton();
        }
    }

    public function destroyMapButtons() {
        while ( mapButtons.length > 0) {
            var mapButton = mapButtons.pop();
            mapButton.hide();
            removeComponent(mapButton);
            // TODO: how to actually destroy this component?
        }
    }

    @:bind(buttonPrevious, MouseEvent.MOUSE_OVER)
    @:bind(buttonNext, MouseEvent.MOUSE_OVER)
    private function onHoverSideButtons(e:MouseEvent) {
        listContents.disableInteractivity(true);
    }

    @:bind(buttonPrevious, MouseEvent.MOUSE_OUT)
    @:bind(buttonNext, MouseEvent.MOUSE_OUT)
    private function onHoverEndSideButtons(e:MouseEvent) {
        listContents.disableInteractivity(false);
    }

    @:bind(buttonPrevious, MouseEvent.CLICK)
    private function onPrevious(e:MouseEvent) {
        mapScroll.hscrollPos -= mapScroll.width;
    }

    @:bind(buttonNext, MouseEvent.CLICK)
    private function onNext(e:MouseEvent) {
        mapScroll.hscrollPos += mapScroll.width;
        //mapScroll.hscrollPos += mapScroll.hscrollPageSize;
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