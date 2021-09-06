package ;

import haxe.io.Path;
import haxe.ui.events.MouseEvent;
import haxe.Timer;
import haxe.ui.core.Screen;
import haxe.ui.containers.VBox;
import haxe.ui.events.ItemEvent;
import datetime.DateTime;

/** draw menu bar, handle notifications and logging
    TEMPORARILY DISABLED, HALF-FINISHED WITH BUGS
 **/
@:build(haxe.ui.ComponentBuilder.build("assets/notify.xml"))
class Notify extends VBox {

    public static var instance:Notify;
    static inline var REFRESH_INTERVAL = 1;
    static inline var DISAPPEAR_TIME = 15;

    var unreadCount = 0;
    var refreshTimer:Timer = new Timer( REFRESH_INTERVAL * 1000);

    public static function init() {
        instance = new Notify();
        return instance;
    }

    private function new() {
        super();
        hideFullNotifications();
        refresh();
        refreshTimer.run = refresh;
    }

    public override function onResized() {
        super.onResized();
        refresh();
    }

    public function showFullNotifications() {
        notifyList.dataSource.filter( function(index, item) {
            return true; // this example will filter out any odd items
        } );
    }

    public function hideFullNotifications() {
        notifyList.dataSource.filter( function(index, item) {
            return item.visible; // this example will filter out any odd items
        } );
    }

    function refresh() {
        for( i in 0...notifyList.dataSource.size ) {
            var data = notifyList.dataSource.get(i);
            if ( data == null || data.visible == false )
                continue;
            data.notifyTime = Database.getRelativeTime(data.time);
            if ( (DateTime.local() - data.time).getTotalSeconds() >= DISAPPEAR_TIME ) {
                // notifyList.dataSource.removeAt(i);
                data.visible = false;
            }
        }

        left = Screen.instance.width * 0.62;
        width = Screen.instance.width * 0.36;
        top = Screen.instance.height - height;
    }

    /** helper for Notify.instance.addNotify() **/
    public static function notify(mapID:String, notifyMessage:String) {
        var timestamp = DateTime.local();
        trace(timestamp.format("%T") + '($mapID) ' + notifyMessage);

        // disabled half-finished Notifications system
        // if ( instance == null ) {
        //     trace('Overlay instance was null, could not notify for $mapID : $notifyMessage');
        //     return;
        // }
        // instance.addNotify( mapID, notifyMessage );
    }

    public function addNotify(mapID:String, notifyMessage:String) {
        var timestamp = DateTime.local();

        var mapThumbImagePath = Path.addTrailingSlash(Main.CACHE_PATH) + mapID + Downloader.thumbnailSuffix;
        Downloader.instance.allocateAndCacheImage(mapThumbImagePath);
        // TODO: load placeholder image if null

        notifyList.dataSource.add( {notifyImage: mapThumbImagePath, notifyID: mapID, notifyText: notifyMessage, time: timestamp, visible: true, notifyTime: Database.getRelativeTime(timestamp)} );
        Screen.instance.setComponentIndex(this, Screen.instance.rootComponents.length );
        trace(timestamp.format("%T") + " - " + notifyMessage);
        refresh();

        unreadCount++;
    }

    @:bind(notifyList, ItemEvent.COMPONENT_EVENT)
    private function onComponentEvent(e:ItemEvent) {
        if ( e.source.id == "notifyZoom" ) {
            MapProfile.openMapProfile( Database.instance.db[e.data.notifyID] );
        }
        if ( notifyList.dataSource.get(e.itemIndex).visible ) {
            notifyList.dataSource.removeAt( e.itemIndex ); // dismiss permanently
        } else {
            notifyList.dataSource.get(e.itemIndex).visible = false;
        }
        unreadCount--;
        refresh();
    }

    

}