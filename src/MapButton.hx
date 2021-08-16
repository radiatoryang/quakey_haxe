package;

import sys.FileSystem;
import hxd.res.Loader;
import haxe.ui.containers.TableView;
import haxe.ui.assets.ImageInfo;
import haxe.ui.backend.heaps.TileCache;
import haxe.ui.ToolkitAssets;
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
    static var loader:Loader;

    var uiTitle:Label;
    // var uiBody:Label;

    public function new() {
        super();
    
        width = 300;
        height = 225;
        includeInLayout = true;

        if ( loader == null) {
            loader = new hxd.res.Loader( new hxd.fs.LocalFileSystem(Main.BASE_DIR, "") );
        }

        // uiBody = new Label();
        // addComponent(uiBody);
    }

    public override function onInitialize() {
        super.onInitialize();

        uiTitle = new Label();
        uiTitle.text = mapData.title;
        uiTitle.padding = 16;
        uiTitle.backgroundColor = "black";
        addComponent(uiTitle);

        tooltip = "by " + mapData.authors.join(", ") + "\n" + mapData.description.substr(0, 64);

        var localPath = Main.CACHE_PATH + "/" + mapData.id + "_injector.jpg";
        var fullPath = Main.BASE_DIR + localPath;
        var fullPathWindows = Main.BASE_DIR + localPath.replace("/", "\\");
        if ( !FileSystem.exists(fullPathWindows) ) {
            var url = "https://www.quaddicted.com/reviews/screenshots/" + mapData.id + "_injector.jpg";
            var http = new haxe.Http(url);
            http.onBytes = function(bytes) { 
                trace("saving to " + Main.BASE_DIR + localPath);
                File.saveBytes(fullPathWindows, bytes); 
                loadImage(localPath);
            }
            http.onError = function(status) { trace("error: " + status); }
            http.request();
        } else {
            loadImage(localPath);
        }
    }

    function loadImage(filepath:String) {
        // temporarily override the image loader to fetch the image
        var oldLoader = hxd.Res.loader;
        hxd.Res.loader = loader;

        // double check the file exists
        if ( !loader.exists(filepath) ) {
            return;
        }

        // double check the file has JPEG headers
        var bytes = loader.load(filepath).entry.getBytes();
        if ( bytes.get(0) != 0xFF || bytes.get(1) != 0xD8 ) {
            return;
        }

        ToolkitAssets.instance.getImage(filepath, getImage);

        backgroundImage = filepath; 

        hxd.Res.loader = oldLoader;
    }

    function getImage(imageInfo:ImageInfo) {

    }

    // @:access(ToolkitAssets)
    // function cacheImage(filepath:String, resourceID:String) {
     //    var loader = new hxd.res.Loader(new hxd.fs.LocalFileSystem(Main.BASE_DIR, ""));
    //     var imageInfo = loader.load(filepath).toImage().getInfo();
    //     ToolkitAssets.instance._imageCache.set(resourceID, imageInfo);
    // }

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