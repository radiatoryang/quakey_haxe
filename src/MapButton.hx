package;

import Database.MapEntry;
import haxe.ui.events.MouseEvent;
import haxe.ui.components.Button;
using StringTools;
using DateTools;

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

        tooltip = "by " + mapData.authors[0] + (mapData.authors.length > 1 ? " + " + mapData.authors.length + " others\n" : "\n" ) + (mapData.date != null ? mapData.date.format(" %d %B %Y") : " ");
        borderSize = 0;

        Downloader.instance.getImageAsync(mapData.id + "_injector.jpg", onImageLoaded );
    }

    public function onImageLoaded(filepath:String) {
        filepath = Downloader.instance.allocateAndCacheImage(filepath);
    
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
        MapProfile.openMapProfile( mapData );
    }    

    // function set_nodeBody(newNodeBody) {
    //     nodeBody = newNodeBody;
    //     uiBody.text = newNodeBody;
    //     return newNodeBody;
    // }

}