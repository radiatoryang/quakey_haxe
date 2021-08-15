package ;

import haxe.ui.containers.HBox;
import hxd.Window.DisplayMode;
import h2d.Font.SDFChannel;
import haxe.ui.core.TextDisplay;
import haxe.ui.backend.TextDisplayImpl;
import haxe.ui.Toolkit;
import haxe.ui.HaxeUIApp;

class Main {

    static var db:Database;
    public static var app:HaxeUIApp;
    static var mainView:MainView;

    public static function main() {
        app = new HaxeUIApp();
        app.ready(function() {
            Toolkit.theme = "dark";
            TextDisplayImpl.channel = SDFChannel.Alpha;
            TextDisplayImpl.alphaCutoff = 0.5;
            TextDisplayImpl.smoothing = 0.05;

            mainView = new MainView();
            app.addComponent(mainView);
            app.start();

            // hxd.Window.getInstance().displayMode = DisplayMode.FullscreenResize;
            hxd.Window.getInstance().title = "Quakey";

            db = new Database();

            var queue = mainView.findComponent("queue", MapList);
            var count = 0;
            for( mapData in db.db ) {
                queue.addMapButton(mapData);
                count++;
                if ( count > 8) {
                    break;
                }
            }
        });
    }
}
