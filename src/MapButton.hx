package;

import Database.MapEntry;
import haxe.ui.containers.Box;
import haxe.ui.events.MouseEvent;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.containers.VBox;

class MapButton extends Button {

    public var mapData:MapEntry;

    var uiTitle:Label;
    // var uiBody:Label;

    public function new() {
        super();
    
        width = 300;
        height = 225;
        includeInLayout = true;

        // uiBody = new Label();
        // addComponent(uiBody);
    }

    public override function onInitialize() {
        super.onInitialize();

        uiTitle = new Label();
        uiTitle.text = mapData.title;
        uiTitle.padding = 16;
        addComponent(uiTitle);

        tooltip = "by " + mapData.authors.join(", ") + "\n" + mapData.description.substr(0, 64);
    }

    @:bind(this, MouseEvent.CLICK)
    function onMapClick(e) {
        var mapProfile = new MapProfile();
        mapProfile.percentWidth = 100;
        mapProfile.percentHeight = 100;
        mapProfile.mapData = mapData;
        Main.app.addComponent(mapProfile);
    }    

    // function set_nodeBody(newNodeBody) {
    //     nodeBody = newNodeBody;
    //     uiBody.text = newNodeBody;
    //     return newNodeBody;
    // }

}