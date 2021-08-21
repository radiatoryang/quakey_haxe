package;

import Database.MapStatus;
import haxe.ui.components.Label;
import Database.MapEntry;
import haxe.ui.events.MouseEvent;
import haxe.ui.components.Button;
using StringTools;

class MapButton extends Button {

    public var mapData:MapEntry;

    var uiTitle:LabelOutlined;
    var uiState:Label;

    public function new() {
        super();
    
        width = 300;
        height = 225;
        includeInLayout = true;
    }

    public override function onInitialize() {
        super.onInitialize();

        uiTitle = new LabelOutlined();
        uiTitle.text = mapData.title;
        uiTitle.padding = 16;
        // uiTitle.backgroundColor = "black";
        // uiTitle.opacity = 0.5;
        addComponent(uiTitle);

        uiState = new Label();
        uiState.addClass("badge");
        addComponent(uiState);

        tooltip = "by " + mapData.authors[0] + (mapData.authors.length > 1 ? " + " + mapData.authors.length + " others" : "" ) + (mapData.date != null ? mapData.date.format(" (%Y)") : "");
        borderSize = 0;

        refreshMapButton();

        Downloader.instance.getImageAsync(mapData.id + "_injector.jpg", onImageLoaded );
    }

    public function onImageLoaded(filepath:String) {
        filepath = Downloader.instance.allocateAndCacheImage(filepath);
    
        if ( filepath != null)
            backgroundImage = filepath;
    }

    public function refreshMapButton() {
        var state = Database.instance.getMapStatus(mapData.id);
        uiState.text = switch(state) {
            case NotQueued: "";
            case Queued: "DOWNLOADING...";
            case Downloaded: "INSTALLING...";
            case Installed: "READY TO PLAY";
        }
        uiState.hidden = uiState.text == "";
    }

    @:bind(this, MouseEvent.CLICK)
    function onMapClick(e) {
        MapProfile.openMapProfile( mapData );
    }    

}