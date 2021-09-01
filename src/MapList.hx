package ;

import haxe.ui.components.Button;
import haxe.ui.containers.HBox;
import haxe.ui.components.Label;
import Database.MapEntry;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;
import haxe.ui.core.Screen;

using DateTools;

@:build(haxe.ui.ComponentBuilder.build("assets/map-list.xml"))
class MapList extends VBox {
    public var mapListName:String = "NEW LIST";
    public var mapListDescription:String = "DESCRIPTION";
    var mapButtons:Array<MapButton> = new Array<MapButton>();
    // public var listContents:HBox;

    public function new() {
        super();
    }

    public override function onInitialize() {
        super.onInitialize();
        listContents = findComponent("listContents", HBox);
        findComponent("listName", Label).text = mapListName;
        updateDescription( mapListDescription );
    }

    public function updateDescription(newDescription:String) {
        mapListDescription = newDescription;
        findComponent("listDescription", Label).text = mapListDescription;
    }

    public function addMapButton(mapData:MapEntry) {
        var newButton = new MapButton();
        newButton.mapData = mapData;
        listContents.addComponent(newButton);
        mapButtons.push(newButton);
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
        loadMapButtons(-mapScroll.width); // hack... when we update scrollbar instantly, it's too fast for mapButtons to realize they've changed pos, so we manually add offset
    }

    @:bind(buttonNext, MouseEvent.CLICK)
    private function onNext(e:MouseEvent) {
        mapScroll.hscrollPos += mapScroll.width;
        loadMapButtons(mapScroll.width); // hack... when we update scrollbar instantly, it's too fast for mapButtons to realize they've changed
    }

    /** try to fix a weird bug where stale mouse click events / focus would open a previously clicked map profile page, even though we didn't click anywhere near it **/
    // public function blurAllButtons() {
    //     for(button in mapButtons) {
    //         button.focus = false;
    //     }
    // }

    @:bind(mapScroll, haxe.ui.events.ScrollEvent.CHANGE)
    public function onScroll(e) {
        loadMapButtons();
    }

    function loadMapButtons(extraX:Float=0, extraY:Float=0 ) {
        for(button in mapButtons) {
            if ( button.screenX > 0 + extraX && button.screenX < Screen.instance.width + extraX && button.screenY > 0 + extraY && button.screenY < Screen.instance.height + extraY ) {
                button.onVisibleInScreenBounds();
            }
        }
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