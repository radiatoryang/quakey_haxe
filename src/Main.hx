package ;

import hxd.Window.DisplayMode;
import h2d.Font.SDFChannel;
import haxe.ui.core.TextDisplay;
import haxe.ui.backend.TextDisplayImpl;
import haxe.ui.Toolkit;
import haxe.ui.HaxeUIApp;

class Main {

    static var mapData:MapData;

    public static function main() {
        var app = new HaxeUIApp();
        app.ready(function() {
            Toolkit.theme = "dark";
            TextDisplayImpl.channel = SDFChannel.Alpha;
            TextDisplayImpl.alphaCutoff = 0.5;
            TextDisplayImpl.smoothing = 0.1;
            app.addComponent(new MainView());
            app.start();

            // hxd.Window.getInstance().displayMode = DisplayMode.FullscreenResize;
            mapData = new MapData();
        });
    }
}
