package ;

import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;

@:build(haxe.ui.ComponentBuilder.build("assets/main-view.xml"))
class MainView extends VBox {

    public static var instance:MainView;

    public function new() {
        super();
        instance = this;
    }

    override function onInitialize() {
        refreshQueue();

        var newReleases = findComponent("newReleases", MapList);
        var latest = Lambda.array(Database.instance.db);
        latest.sort( (a,b) -> Database.getTotalDays(b.date) - Database.getTotalDays(a.date) );
        for( i in 0...8 ) {
            newReleases.addMapButton( latest[i] );
        }
        
        var rated = Lambda.array(Database.instance.db);

        // TODO: make this generic eventually, so users can add their own categories
        var highlyRated = findComponent("highlyRated", MapList);
        var ratedModern = rated.filter( map -> map.rating >= 4.0 && map.date.getYear() >= 2010 );
        hxd.Rand.create().shuffle(ratedModern);
        for( i in 0... 8) {
            highlyRated.addMapButton( ratedModern[i] );
        }

        var highlyRatedOld = findComponent("highlyRatedOld", MapList);
        var ratedClassic = rated.filter( map -> map.rating >= 4.0 && map.date.getYear() < 2010 );
        hxd.Rand.create().shuffle(ratedClassic);
        for( i in 0... 8) {
            highlyRatedOld.addMapButton( ratedClassic[i] );
        }
    }

    public function refreshQueue() {
        var queue = findComponent("queue", MapList);
        queue.destroyMapButtons(); // clean-up

        if ( UserState.instance.currentData.mapQueue == null)
            return;
        for( queuedMapID in UserState.instance.currentData.mapQueue ) {
            queue.addMapButton( Database.instance.db[queuedMapID] );
        }
        trace("queue is currently: " + UserState.instance.currentData.mapQueue.join(", "));
    }
    
    // @:bind(button2, MouseEvent.CLICK)
    // private function onMyButton(e:MouseEvent) {
    //     button2.text = "Thanks!";
    // }
}