package;

import Database.MapState;
import Database.MapStatus;
import haxe.ui.components.Label;
import Database.MapEntry;
import haxe.ui.events.MouseEvent;
import haxe.ui.components.Button;
using StringTools;

@:build(haxe.ui.ComponentBuilder.build("assets/map-button.xml"))
class MapButton extends Button {

    public var mapData:MapEntry;

    public function new() {
        super();
    }

    public override function onInitialize() {
        super.onInitialize();
        mapTitleText.text = mapData.title;
        tooltip = "by " + mapData.authors[0] + (mapData.authors.length > 1 ? " + " + mapData.authors.length + " others" : "" ) + (mapData.date != null ? mapData.date.format(" (%Y)") : "");
    }

    public function onVisibleInScreenBounds() {
        Downloader.instance.getImageAsync(mapData.id + "_injector.jpg", onImageLoaded );
        Database.instance.subscribeToState(mapData.id, onRefresh);
    }

    public function onRefresh(mapState:MapState) {
        // trace("MapButton.onRefresh for " + mapData.id);
        mapStateText.text = switch(mapState.status) {
            case NotQueued: "";
            case Queued: "QUEUED";
            case Downloading: "DOWNLOADING ";
            case Downloaded: "INSTALLING";
            case Installed: "READY";
        }
        if ( mapState.status == Downloading ) {
            mapStateText.text += Std.string(Math.round(mapState.downloadProgress * 100)) + "%";
        }
        mapStateText.hidden = mapStateText.text == "";
    }

    public function onImageLoaded(filepath:String) {
        filepath = Downloader.instance.allocateAndCacheImage(filepath);
    
        if ( filepath != null)
            backgroundImage = filepath;
    }

    @:bind(this, MouseEvent.CLICK)
    function onMapClick(e) {
        MapProfile.openMapProfile( mapData );
    }    

}