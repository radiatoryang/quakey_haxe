package ;

import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.components.Slider;
import haxe.ui.containers.VBox;
import Database.MapEntry;

using StringTools;

@:build(haxe.ui.ComponentBuilder.build("assets/search.xml"))
class Search extends VBox {
    public static var instance:Search;

    var currentSearchObject:SearchGroup;
    var currentSearchResults:Array<MapEntry>;
    var currentSearchButtons:Array<MapButton> = new Array<MapButton>();
    var disableAutoRefresh = false;

    public static function init() {
        instance = new Search();
        return instance;
    }

    private function new() {
        super();
        disableAutoRefresh = true;
    }

    override function onResized() {
        super.onResized();
    }

    private function resetSliders() {

    }

    public function showSearch(?searchQuery:String, ?textFilter:TextFilter) {
        disableAutoRefresh = true;
        show();
        Main.moveToFrontButBeneathNotifications(this);
        MainView.moveBelowMenuBar(this);

        searchBar.text = searchQuery != null ? searchQuery : "";
        resetSliders();

        refreshSearch(null);
        disableAutoRefresh = false;
    }

    @:bind(searchBar, UIEvent.CHANGE)
    @:bind(checkTitle, MouseEvent.CLICK)
    @:bind(checkTags, MouseEvent.CLICK)
    @:bind(checkAuthors, MouseEvent.CLICK)
    @:bind(checkDescription, MouseEvent.CLICK)
    @:bind(yearSlider, UIEvent.CHANGE)
    @:bind(sizeSlider, UIEvent.CHANGE)
    @:bind(ratingSlider, UIEvent.CHANGE)
    @:bind(authorCountSlider, UIEvent.CHANGE)
    private function refreshSearch(e) {
        if ( disableAutoRefresh )
            return;

        trace("refreshing search");

        // generate all the data we need
        currentSearchObject = generateSearchObject();
        currentSearchResults = getSearchResults(currentSearchObject);

        // clear current search result buttons (TODO: is pooling necessary? a better way to do this?)
        while(currentSearchButtons.length > 0) {
            var oldButton = currentSearchButtons.pop();
            oldButton.hide();
            oldButton.dispose();
        }
        for(result in currentSearchResults) {
            var newButton = new MapButton();
            currentSearchButtons.push(newButton);
            newButton.mapData = result;
            searchContents.addComponent(newButton);
        }

    }

    /** based on all the current Search UI settings, generate a search query object group **/
    public function generateSearchObject():SearchGroup {
        var textFilters = new Array<SearchText>();
        if ( checkTitle.selected )
            textFilters.push( { query: searchBar.text, filterType:TextFilter.Title } );
        if ( checkTags.selected )
            textFilters.push( { query: searchBar.text, filterType:TextFilter.Tags } );
        if ( checkAuthors.selected )
            textFilters.push( { query: searchBar.text, filterType:TextFilter.Author } );
        if ( checkDescription.selected )
            textFilters.push( { query: searchBar.text, filterType:TextFilter.Description } );

        var numberFilters = new Array<SearchNumber>();
        if ( isSliderUsed(yearSlider) )
            numberFilters.push( { min: 1996 + yearSlider.start, max: 1996 + yearSlider.end, filterType: NumberFilter.Year} );
        if ( isSliderUsed(sizeSlider) )
            numberFilters.push( { min: sizeSlider.start, max: sizeSlider.end, filterType: NumberFilter.Size} );
        if ( isSliderUsed(ratingSlider) )
            numberFilters.push( { min: ratingSlider.start, max: ratingSlider.end, filterType: NumberFilter.RatingPercent} );
        if ( isSliderUsed(authorCountSlider) )
            numberFilters.push( { min: authorCountSlider.start, max: authorCountSlider.end, filterType: NumberFilter.AuthorCount} );

        // TODO: sorting

        return {textFilters: textFilters, numberFilters: numberFilters};
    }

    private inline function isSliderUsed(slider:Slider):Bool {
        if (slider.start - slider.min >= slider.step - 0.01 || slider.max - slider.end >= slider.step - 0.01)  // -0.01 is a big chunky epsilon to account for floating point inaccuracy
            return true;
        else
            return false;
    }

    /** main search function; static because user-generated playlists in MainView will also use this search to populate themselves, this isn't just for search page!
        also blocking / happens in a single frame, hopefully it's fast enough where we don't need to thread it
     **/
    public static function getSearchResults(searchGroup:SearchGroup) {  
        var allMaps = Lambda.array(Database.instance.db);
        var results = new Array<Database.MapEntry>();
        
        for( mapEntry in allMaps ) {
            if ( doesMapMatchAny(mapEntry, searchGroup.textFilters) && doesMapMatchAll(mapEntry, searchGroup.numberFilters) )
                results.push(mapEntry);
        }

        return results;
    }

    private static function doesMapMatchAny(mapEntry:Database.MapEntry, textFilters:Array<SearchText>):Bool {
        for( filter in textFilters) {
            switch (filter.filterType) {
                case Title:
                    if (mapEntry.title != null && (filter.query == null || mapEntry.title.toLowerCase().contains(filter.query)) ) {
                        return true;
                    }
                case Author:
                    if (mapEntry.authors != null && (filter.query == null || mapEntry.authors.join(" ").toLowerCase().contains(filter.query)) ) {
                        return true;
                    }
                case Tags:
                    if (mapEntry.tags != null && (filter.query == null || mapEntry.tags.join(" ").contains(filter.query)) ) {
                        return true;
                    }
                case Description:
                    if (mapEntry.description != null && (filter.query == null || mapEntry.description.toLowerCase().contains(filter.query)) ) {
                        return true;
                    }
            }
        }
        return false;
    }

    private static function doesMapMatchAll(mapEntry:Database.MapEntry, numberFilters:Array<SearchNumber>):Bool {
        for( filter in numberFilters) {
            switch (filter.filterType) {
                case Year:
                    if (mapEntry.date == null || mapEntry.date.getYear() < filter.min || mapEntry.date.getYear() > filter.max ) {
                        return false;
                    }
                case Size:
                    if (mapEntry.size == null || mapEntry.size < filter.min || mapEntry.size > filter.max) {
                        return false;
                    }
                case AuthorCount:
                    if (mapEntry.authors == null || mapEntry.authors.length < filter.min || mapEntry.authors.length > filter.max ) {
                        return false;
                    }
                case RatingPercent:
                    if (mapEntry.ratingPercent == null || mapEntry.ratingPercent < filter.min || mapEntry.ratingPercent > filter.max ) {
                        return false;
                    }
            }
        }
        return true;
    }

    public static function getSortedMaps(mapArray:Array<Database.MapEntry>, sort:SearchSort) {
        var sortedArray = mapArray.copy();
        switch (sort.sortType) {
            case Shuffle:
                return hxd.Rand.create().shuffle(sortedArray);
            case Title:
                if ( sort.ascending )
                    return sortedArray.sort( (a,b) -> sortAlphabetically(a.title, b.title) );
                else
                    return sortedArray.sort( (b,a) -> sortAlphabetically(a.title, b.title) );
            case Year:
                if ( sort.ascending )
                    return sortedArray.sort( (a, b) -> (a.date != null ? a.date.getYear() : 0) - (b.date != null ? b.date.getYear() : 0) );
                else 
                    return sortedArray.sort( (b, a) -> (a.date != null ? a.date.getYear() : 0) - (b.date != null ? b.date.getYear() : 0) );
            case Size:
                if ( sort.ascending )
                    return sortedArray.sort( (a, b) -> Math.round((a.size != null ? a.size : 0) - (b.size != null ? b.size : 0)) );
                else 
                    return sortedArray.sort( (b, a) -> Math.round((a.size != null ? a.size : 0) - (b.size != null ? b.size : 0)) );
            case AuthorCount:
                if ( sort.ascending )
                    return sortedArray.sort( (a, b) -> (a.authors != null ? a.authors.length : 0) - (b.authors != null ? b.authors.length : 0) );
                else 
                    return sortedArray.sort( (b, a) -> (a.authors != null ? a.authors.length : 0) - (b.authors != null ? b.authors.length : 0) );
            case RatingPercent:
                if ( sort.ascending )
                    return sortedArray.sort( (a, b) -> Math.round((a.ratingPercent != null ? a.ratingPercent : 0) - (b.ratingPercent != null ? b.ratingPercent : 0)) );
                else 
                    return sortedArray.sort( (b, a) -> Math.round((a.ratingPercent != null ? a.ratingPercent : 0) - (b.ratingPercent != null ? b.ratingPercent : 0)) );
        }
    }

    public static inline function sortAlphabetically(a:String, b:String):Int {
        a = a.toUpperCase();
        b = b.toUpperCase();
      
        if (a < b) {
          return -1;
        }
        else if (a > b) {
          return 1;
        } else {
          return 0;
        }
    }
}

/** we store searches as objects so we can recall them later OR reuse them for playlist construction etc. **/
typedef SearchGroup = {
    var ?textFilters:Array<SearchText>; // must match ANY, actually the opposite of a filter?
    var ?numberFilters:Array<SearchNumber>; // must match ALL
    var ?sorting:SearchSort;
}

typedef SearchText = {
    var filterType:TextFilter;
    var query:String;
}

enum TextFilter {
    Title;
    Author;
    Tags;
    Description;
}

typedef SearchNumber = {
    var filterType:NumberFilter;
    var min:Float;
    var max:Float;
}

enum NumberFilter {
    Year;
    Size;
    AuthorCount;
    RatingPercent;
}

typedef SearchSort = {
    var sortType:SortFilter;
    var ascending:Bool;
}

enum SortFilter {
    Shuffle;
    Title;
    Year;
    Size;
    AuthorCount;
    RatingPercent;
}