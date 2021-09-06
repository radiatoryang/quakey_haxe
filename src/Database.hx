package ;

import sys.FileSystem;
import haxe.io.Path;
import sys.Http;
import hxd.Math;
import datetime.DateTime;
import sys.io.File;

using StringTools;
using UnicodeString;

/** parses the XML from Quaddicted (description, metadata, install instructions) **/
class Database {

    var xmlData:Xml;
    public static var instance:Database;

    public var db: Map<String, MapEntry> = new Map<String, MapEntry>();
    var states:Map<String, MapState> = new Map<String, MapState>();
    // var signals:Map<String, Signal1<MapState>> = new Map<String, Signal1<MapState>>();
    var signals:Map<String, Array<MapState->Void>> = new Map<String, Array<MapState->Void>>();

    public static function init() {
        if ( !FileSystem.exists(Main.BASE_DIR + Path.addTrailingSlash(Main.CACHE_PATH) + "quaddicted_database.xml") ) {
            throw "No XML database file was found, not even an old cached version? Expected to find the file at " 
            + Main.BASE_DIR + Path.addTrailingSlash(Main.CACHE_PATH) + "quaddicted_database.xml";
        }
        instance = new Database();
    }

    private function new() {
        instance = this;

        var htmlStripRegex = ~/<[^>]*>/g;
        xmlData = Xml.parse( File.getContent( Main.BASE_DIR + Path.addTrailingSlash(Main.CACHE_PATH) + "quaddicted_database.xml" ) );
        var root = xmlData.firstElement();
        for (file in root.elementsNamed("file")) {
            var id = file.get("id");
            var titleText = id;
            var md5 = "";
            var authors = new Array<String>();
            var description = id;
            var descriptionLinks = new Array<String>();
            var date:Date = null;
            var size = -1.0;
            var tags = new Array<String>();
            var rating = Std.parseFloat(file.get("normalized_users_rating"));
            var ratingPercent = Math.round(Math.sqrt(rating * 0.2) * 100);
            
            for(titleString in file.elementsNamed("title")) {
                titleText = titleString.firstChild().nodeValue.trim();
                if ( titleText == "Title" || titleText == "Untitled" ) {
                    titleText = id;
                }
            }

            for (sumString in file.elementsNamed("md5sum")) {
                md5 = sumString.firstChild().nodeValue.trim();
            }

            for(authorString in file.elementsNamed("author")) {
                var lotsOfAuthors = authorString.firstChild().nodeValue.replace("&amp;", "&").split(",");
                for(stillMaybeMultipleAuthor in lotsOfAuthors) {
                    var multipleAuthors = stillMaybeMultipleAuthor.split('&'); // TODO: convert to regex
                    for (authorName in multipleAuthors) {
                        authors.push( authorName.trim() );
                    }
                }
            }

            for (descString in file.elementsNamed("description")) {
                description = descString.firstChild().nodeValue.trim().replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n");
                // extract links to other Quaddicted pages
                if ( description.contains("href") ) {
                    var descSplit = description.split('href="');
                    for (i in 1...descSplit.length) {
                        var link = descSplit[i].split('"')[0];
                        if ( link.endsWith(".html")) { // must parse "ad_v1_70final.html" and "/reviews/nehahra.html" as well as "http://www.quaddicted.com/reviews/quoth.html"
                            if ( link.contains("reviews/") || (!link.startsWith("http") && !link.startsWith("www")) ) {
                                var linkSplit = link.split("/"); 
                                var linkID = linkSplit[linkSplit.length-1].substring( 0, linkSplit[linkSplit.length-1].length - ".html".length );
                                descriptionLinks.push( linkID );
                            } 
                        }
                        // trace("found href=" + descSplit[i] " ... parsed into: " +  );
                    }
                }

                // now strip all HTML
                description = htmlStripRegex.replace(description, "");
            }

            for (dateString in file.elementsNamed("date")) {
                var dateData = dateString.firstChild().nodeValue.trim().split(".");
                date = DateTime.fromString(dateData[2] + "-" + dateData[1] + "-" + dateData[0]);
            }

            for (sizeString in file.elementsNamed("size")) {
                size = Math.round( Std.parseInt(sizeString.firstChild().nodeValue.trim()) / 100.0 ) / 10.0;
            }

            for(tagElement in file.elementsNamed("tags")) {
                for (tagString in tagElement.elementsNamed("tag")) {
                    tags.push(tagString.firstChild().nodeValue.trim()); 
                }   
            }

            var techInfo: TechInfo = { };
            for(techInfoElement in file.elementsNamed("techinfo")) {
                for(zipString in techInfoElement.elementsNamed("zipbasedir")) {
                    techInfo.zipbasedir = zipString.firstChild().nodeValue.trim();
                }
                for(commandString in techInfoElement.elementsNamed("commandline")) {
                    techInfo.commandline = commandString.firstChild().nodeValue.trim();
                }
                for(reqElement in techInfoElement.elementsNamed("requirements")) {
                    techInfo.requirements = new Array<String>();
                    for( fileString in reqElement.elementsNamed("file") ) {
                        techInfo.requirements.push( fileString.get("id") );
                    }
                }
                techInfo.startmap = new Array<String>();
                for(startmapElement in techInfoElement.elementsNamed("startmap")) {
                    techInfo.startmap.push( startmapElement.firstChild().nodeValue.trim() );
                }
            }

            db.set( id, {
                id: id, 
                title: titleText, 
                md5sum: md5,
                authors: authors, 
                description: description, 
                date: date, 
                size: size, 
                rating: rating,
                ratingPercent: ratingPercent,
                tags: tags,
                techinfo: techInfo,
                links: descriptionLinks
            } );
        }

        // DEBUG TESTS
        // var debugCount = 0;
        // for (mapData in db) {
        //     Downloader.getModInstallFolderSuffix(mapData);
        //     debugCount++;
        //     if ( debugCount > 256) {
        //         break;
        //     }
        // }
        // trace("suffix test complete!");
    }

    // TODO: will have to refactor for localization?
    public static function getMonthName(monthNumber:Int) {
        return switch( monthNumber ) {
            case January: return "January";
            case February: return "February";
            case March: return "March";
            case April: return "April";
            case May: return "May";
            case June: return "June";
            case July: return "July";
            case August: return "August";
            case September: return "September";
            case October: return "October";
            case November: return "November";
            case December: return "December";
            default: return Std.string(monthNumber);
        }
    }
    
    public static inline function getTotalDays(date:DateTime) {
        return date.getYear() * 365 + date.getMonth() * 31 + date.getDay();
    }

    public static function getRelativeTime(date:DateTime) {
        var now = DateTime.local();
        var span = now - date;

        if ( span.getTotalMonths() > 1 ) {
            return span.formatPartial(['%y years', '%m months']).join(', ') + " ago";
        } else if ( span.getTotalHours() > 24 ) {
            return span.format("%a days ago");
        } else if ( span.getTotalHours() > 1 ) {
            return span.format("%c hours ago");
        } else if ( span.getTotalMinutes() > 1) {
            return span.format("%e minutes ago");
        } else {
            return "just now";
        }
    }

    // public function getMapStatus(mapID:String) {
    //     if ( Downloader.isModInstalled(mapID) ) {
    //         return MapStatus.Installed;
    //     } else if ( Downloader.isMapDownloaded(mapID) ) {
    //         return MapStatus.Downloaded;
    //     } else if ( mapID == Downloader.instance.currentMapDownloadID ) {
    //         return MapStatus.Downloading;
    //     } else if (UserState.instance.isMapQueued(mapID) ) {
    //         return MapStatus.Queued;
    //     } else {
    //         return MapStatus.NotQueued;
    //     }
    // }

    public static function refreshAllStates() {
        for( mapID => state in instance.states) {
            instance.refreshState(mapID);
        }
    }

    public function getState(mapID:String, noRefresh=false) {
        if ( !states.exists(mapID) ) {
            states.set(mapID, {status: NotQueued, downloadProgress: 0.0});
        } 
        return noRefresh ? states[mapID] : refreshState(mapID);
    }

    public function refreshState(mapID:String) {
        if ( !states.exists(mapID) ) {
            states.set(mapID, {status: NotQueued, downloadProgress: 0.0});
        }

        if ( Downloader.isModInstalled(mapID) ) {
            states[mapID].status = MapStatus.Installed;
        } else if ( Downloader.instance.installQueue.contains(mapID) ) {
            states[mapID].status = MapStatus.Installing;
        } else if ( Downloader.isMapDownloaded(mapID) ) {
            states[mapID].status = MapStatus.Downloaded;
        } else if ( mapID == Downloader.instance.currentMapDownloadID ) {
            states[mapID].status = MapStatus.Downloading;
            states[mapID].downloadProgress = Math.clamp(Downloader.instance.getCurrentMapDownloadProgress(), 0, 1.0);
        } else if (UserState.instance.isMapQueued(mapID) ) {
            states[mapID].status = MapStatus.Queued;
        } else {
            states[mapID].status = MapStatus.NotQueued;
        }

        if ( signals.exists(mapID) ) {
            // signals[mapID].dispatch(states[mapID]);
            for( callback in signals[mapID] ) {
                if ( callback != null)
                    callback(states[mapID]);
            }
        }

        return states[mapID];
    }

    public function subscribeToState(mapID:String, callback:MapState->Void) {
        if ( !signals.exists(mapID) ) {
            signals.set(mapID, new Array<MapState->Void>());
        }
        signals[mapID].push( callback );
        refreshState(mapID);
    }
}

typedef MapEntry = {
    var id:String;
    var title:String;
    
    var ?md5sum:String;

    /** in megabytes, to the nearest tenth **/
    var ?size:Float;
    var ?date:DateTime;
    var ?description:String;
    var ?rating:Float;
    var ?authors:Array<String>;
    var ?tags:Array<String>;
    var ?techinfo:TechInfo;

    // BELOW: extra info generated by Quakey, diverges away from Quaddicted XML file format from here

    /** other mapIDs parsed from the description, we can't render HTML in this app **/
    var ?links:Array<String>;

    /** 0-100% score... because displaying the raw normalized user score from Quaddicted is a bit misleading and implies the map is rated a lot worse than it actually is!
    so instead, we divide by 5 and square root, to sort of un-normalize the raw score, which imo is a better indicator **/
    var ?ratingPercent:Float;
}

typedef TechInfo = {
    var ?zipbasedir:String;
    var ?commandline:String;
    var ?startmap:Array<String>;
    var ?requirements:Array<String>;
}

typedef MapState = {
    var status:MapStatus;
    var downloadProgress:Float;
}

enum MapStatus {
    NotQueued;
    Queued;
    Downloading;
    Downloaded;
    Installing;
    Installed;
}