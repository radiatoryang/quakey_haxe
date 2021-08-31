package ;

import haxe.ui.events.ScrollEvent;
import haxe.ui.core.Screen;
import haxe.ui.core.Component;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;

@:build(haxe.ui.ComponentBuilder.build("assets/main-view.xml"))
class MainView extends VBox {

    public static var instance:MainView;
    public static inline var MENU_BAR_HEIGHT = 48;
    var mapLists: Array<MapList> = new Array<MapList>();

    public function new() {
        super();
        instance = this;
    }

    override function onInitialize() {
        refreshQueue();
        mapLists.push( findComponent("queue") );

        var newReleases = findComponent("newReleases", MapList);
        var latest = Lambda.array(Database.instance.db);
        latest.sort( (a,b) -> Database.getTotalDays(b.date) - Database.getTotalDays(a.date) );
        for( i in 0...8 ) {
            newReleases.addMapButton( latest[i] );
        }

        var mostRecentDateIndex = 0; // idk how date generation or sorting works, but just doing this to be safe
        while ( latest[mostRecentDateIndex].date == null ) {
            mostRecentDateIndex++;
        }
        var recentMonth = Database.getMonthName( latest[mostRecentDateIndex].date.getMonth() );
        newReleases.updateDescription("updated " + latest[mostRecentDateIndex].date.format('%d $recentMonth %Y') );
        mapLists.push(newReleases);
        
        var rated = Lambda.array(Database.instance.db);

        // TODO: make this generic eventually, so users can add their own categories
        var highlyRated = findComponent("highlyRated", MapList);
        var ratedModern = rated.filter( map -> map.rating >= 3.75 && map.date.getYear() >= 2010 );
        hxd.Rand.create().shuffle(ratedModern);
        for( i in 0... 8) {
            highlyRated.addMapButton( ratedModern[i] );
        }
        mapLists.push(highlyRated);

        var highlyRatedOld = findComponent("highlyRatedOld", MapList);
        var ratedClassic = rated.filter( map -> map.rating >= 3.75 && map.date.getYear() < 2010 );
        hxd.Rand.create().shuffle(ratedClassic);
        for( i in 0... 8) {
            highlyRatedOld.addMapButton( ratedClassic[i] );
        }
        mapLists.push(highlyRatedOld);

        var ratedHard = rated.filter( map -> map.rating >= 3.0 && map.tags != null && map.tags.contains("hard") );
        hxd.Rand.create().shuffle(ratedHard);
        for( i in 0... 8) {
            listHard.addMapButton( ratedHard[i] );
        }
        mapLists.push(listHard);

        var ratedSewer = rated.filter( map -> map.rating >= 3.0 && map.tags != null && (map.tags.contains("sewer") || map.tags.contains("sewers") || map.tags.contains("cistern")) );
        hxd.Rand.create().shuffle(ratedSewer);
        for( i in 0... 8) {
            listSewer.addMapButton( ratedSewer[i] );
        }
        mapLists.push(listSewer);
    }

    public function showMainView() {
        Main.moveToFrontButBeneathNotifications( this );
        moveBelowMenuBar(this);
    }

    // public function refreshAllMapButtons() {
    //     for( list in mapLists) {
    //         list.refreshMapButtons();
    //     }
    // }

    public function refreshQueue() {
        var queue = findComponent("queue", MapList);
        queue.destroyMapButtons(); // clean-up

        if ( UserState.instance.currentData.mapQueue == null)
            return;

        for( queuedMapID in UserState.instance.currentData.mapQueue ) {
            queue.addMapButton( Database.instance.db[queuedMapID] );
        }
        queue.updateDescription(UserState.instance.currentData.mapQueue.length + " items");

        trace("queue is currently: " + UserState.instance.currentData.mapQueue.join(", "));
    }

        // public function blurAllMapButtons() {
    //     for( list in mapLists) {
    //         list.blurAllButtons();
    //     }
    // }

    @:bind(mainScroll, ScrollEvent.CHANGE)
    private function onScroll(e) {
        for( mapList in mapLists ) {
            if ( mapList.screenTop < Screen.instance.height ) {
                mapList.onScroll(null);
            }
        }
    }

    public static function moveBelowMenuBar(comp:Component) {
        comp.left = 0;
        comp.top = MainView.MENU_BAR_HEIGHT;
        comp.height = haxe.ui.core.Screen.instance.height - MainView.MENU_BAR_HEIGHT;
    }
}