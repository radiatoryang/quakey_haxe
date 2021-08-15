package;

import haxe.ui.events.MouseEvent;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.containers.VBox;

class MapButton extends Button {

    public var mapTitle(default, set):String;

    public var mapID:String;

    var uiTitle:Label;
    // var uiBody:Label;

    public function new() {
        super();
    
        width = 300;
        height = 225;
        includeInLayout = true;

        // uiBody = new Label();
        // addComponent(uiBody);

        uiTitle = new Label();
        addComponent(uiTitle);
    }

    @:bind(this, MouseEvent.CLICK)
    function onMapClick(e) {
        trace("clicked button for " + mapID);
    }    

    function set_mapTitle(newMapTitle) {
        mapTitle = newMapTitle;
        uiTitle.text = newMapTitle;
        return newMapTitle;
    }

    // function set_nodeBody(newNodeBody) {
    //     nodeBody = newNodeBody;
    //     uiBody.text = newNodeBody;
    //     return newNodeBody;
    // }

}