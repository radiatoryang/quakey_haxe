package ;

import haxe.ui.events.MouseEvent;
import haxe.ui.containers.HBox;

/** draw menu bar, handle notifications and logging **/
@:build(haxe.ui.ComponentBuilder.build("assets/overlay.xml"))
class Overlay extends HBox {

    public static var instance:Overlay;

    public static function init() {
        instance = new Overlay();
        return instance;
    }

    private function new() {
        super();
    }

    @:bind(homeButton, MouseEvent.CLICK)
    public function openHome(e:MouseEvent) {
        MainView.instance.showMainView();
    }
    
    @:bind(configButton, MouseEvent.CLICK)
    private function openConfig(e:MouseEvent) {
        Config.instance.show();
    }

    @:bind(searchButton, MouseEvent.CLICK)
    private function openSearch(e:MouseEvent) {
        Search.instance.showSearch();
    }

}