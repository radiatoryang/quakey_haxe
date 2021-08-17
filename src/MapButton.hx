package;

import h2d.filter.Filter;
import haxe.ui.styles.Style;
import h2d.filter.Glow;
import sys.FileSystem;
import sys.io.File;
import Database.MapEntry;
import haxe.ui.containers.Box;
import haxe.ui.events.MouseEvent;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.containers.VBox;
using StringTools;

class MapButton extends Button {

    public var mapData:MapEntry;

    var uiTitle:LabelOutlined;
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

        uiTitle = new LabelOutlined();
        uiTitle.text = mapData.title;
        uiTitle.padding = 16;
        // uiTitle.backgroundColor = "black";
        // uiTitle.opacity = 0.5;
        
        addComponent(uiTitle);

        tooltip = "by " + mapData.authors.join(", ") + "\n" + mapData.description.substr(0, 64);

        Main.getImageAsync(mapData.id + "_injector.jpg", onImageLoaded );
    }

    public function onImageLoaded(filepath:String) {
        filepath = Main.allocateAndCacheImage(filepath);
    
        if ( filepath != null)
            backgroundImage = filepath;
    }


    // @:access(ToolkitAssets)
    // function cacheImage(filepath:String, resourceID:String) {
     //    var loader = new hxd.res.Loader(new hxd.fs.LocalFileSystem(Main.BASE_DIR, ""));
    //     var imageInfo = loader.load(filepath).toImage().getInfo();
    //     ToolkitAssets.instance._imageCache.set(resourceID, imageInfo);
    // }

    @:bind(this, MouseEvent.CLICK)
    function onMapClick(e) {
        if ( MapProfile.cache.exists(mapData.id)==false ) {
            var mapProfile = new MapProfile();
            mapProfile.percentWidth = 100;
            mapProfile.percentHeight = 100;
            mapProfile.includeInLayout = false;
            mapProfile.mapData = mapData;
            Main.app.addComponent(mapProfile);
            MapProfile.cache.set(mapData.id, mapProfile);
        }
        var mapProfile = MapProfile.cache[mapData.id];
        mapProfile.show();
        if ( mapProfile.parentComponent != null ) {
            mapProfile.moveComponentToFront();
        }
    }    

    // function set_nodeBody(newNodeBody) {
    //     nodeBody = newNodeBody;
    //     uiBody.text = newNodeBody;
    //     return newNodeBody;
    // }

}