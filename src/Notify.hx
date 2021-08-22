package ;

import haxe.Timer;
import haxe.ui.core.Screen;
import haxe.ui.containers.VBox;
import haxe.ui.events.ItemEvent;
import datetime.DateTime;

/** handles notifications and logging **/
@:build(haxe.ui.ComponentBuilder.build("assets/notify.xml"))
class Notify extends VBox {

    public static var instance:Notify;
    static inline var REFRESH_INTERVAL = 5;
    static inline var DISAPPEAR_TIME = 15;
    var refreshTimer:Timer = new Timer( REFRESH_INTERVAL * 1000);

    public static function init() {
        instance = new Notify();
        return instance;
    }

    private function new() {
        super();
        refresh();
        refreshTimer.run = refresh;
    }

    public override function onResized() {
        super.onResized();
        refresh();
    }

    function refresh() {
        for( i in 0...notifyList.dataSource.size ) {
            var data = notifyList.dataSource.get(i);
            if ( data == null )
                continue;
            data.notifyTime = Database.getRelativeTime(data.time);
            if ( (DateTime.local() - data.time).getTotalSeconds() >= DISAPPEAR_TIME ) {
                notifyList.dataSource.removeAt(i);
            }
        }

        left = Screen.instance.width * (0.99 - percentWidth/100.0);
        top = Screen.instance.height - height;
    }

    public function addNotify(mapID:String, notifyMessage:String) {
        var timestamp = DateTime.local();

        var mapThumbImagePath = Main.CACHE_PATH + "/" + mapID + "_injector.jpg";
        Downloader.instance.allocateAndCacheImage(mapThumbImagePath);
        // TODO: load placeholder image if null

        notifyList.dataSource.add( {notifyImage: mapThumbImagePath, notifyID: mapID, notifyText: notifyMessage, time: timestamp, notifyTime: Database.getRelativeTime(timestamp)} );
        Screen.instance.setComponentIndex(this, Screen.instance.rootComponents.length );
        trace(timestamp.format("%T") + " - " + notifyMessage);
        refresh();
        
    }

    @:bind(notifyList, ItemEvent.COMPONENT_EVENT)
    private function onComponentEvent(e:ItemEvent) {
        if ( e.source.id == "notifyZoom" ) {
            MapProfile.openMapProfile( Database.instance.db[e.data.notifyID] );
        }
        notifyList.dataSource.removeAt( e.itemIndex );
        refresh();
    }
}