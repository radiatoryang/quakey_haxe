package ;

import haxe.ui.core.Screen;
import haxe.ui.containers.VBox;
import haxe.ui.events.ItemEvent;

/** handles notifications via floating sidebar **/
@:build(haxe.ui.ComponentBuilder.build("assets/notify.xml"))
class Notify extends VBox {

    public static var instance:Notify;

    public static function init() {
        instance = new Notify();
        return instance;
    }

    private function new() {
        super();
        refresh();
    }

    public override function onResized() {
        super.onResized();
        refresh();
    }

    function refresh() {
        left = Screen.instance.width * 0.68;
        top = Screen.instance.height * 0.8;
    }

    public function addNotify(mapID:String, notifyMessage:String) {
        // TODO: time stamp?
        notifyList.dataSource.add( {notifyID: mapID, notifyText: notifyMessage} );
        Screen.instance.setComponentIndex(this, Screen.instance.rootComponents.length );
        // trace("notify index is " + Notify.instance.parent.getChildIndex(Notify.instance));
        refresh();
    }

    @:bind(notifyList, ItemEvent.COMPONENT_EVENT)
    private function onComponentEvent(e:ItemEvent) {
        if ( e.source.id == "notifyText" ) {
            MapProfile.openMapProfile( Database.instance.db[e.data.notifyID] );
        }
        notifyList.dataSource.removeAt( e.itemIndex );
    }
}