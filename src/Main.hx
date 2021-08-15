package ;

import haxe.ui.Toolkit;
import haxe.ui.HaxeUIApp;

class Main {
    public static function main() {
        var app = new HaxeUIApp();
        app.ready(function() {
            Toolkit.theme = "dark";
            app.addComponent(new MainView());

            app.start();
        });
    }
}
