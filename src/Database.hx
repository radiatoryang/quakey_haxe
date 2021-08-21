package ;

import datetime.DateTime;
import sys.io.File;

using StringTools;
using UnicodeString;

/** parses the XML from Quaddicted (description, metadata, install instructions) **/
class Database {

    var xmlData:Xml;
    public static var instance:Database = new Database();
    public var db: Map<String, MapEntry> = new Map<String, MapEntry>();

    private function new() {
        instance = this;

        var htmlStripRegex = ~/<[^>]*>/g;

        xmlData = Xml.parse( File.getContent( "quaddicted_database.xml" ) );
        var root = xmlData.firstElement();
        for (file in root.elementsNamed("file")) {
            var id = file.get("id");
            var titleText = id;
            var md5 = "";
            var authors = new Array<String>();
            var description = id;
            var date:Date = null;
            var size = -1.0;
            var rating = Std.parseFloat(file.get("normalized_users_rating"));
            
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
                authors = authorString.firstChild().nodeValue.split(","); // TODO: split on "&" and "&amp;" too
                for(i in 0...authors.length) {
                    authors[i] = authors[i].trim();
                }
            }

            for (descString in file.elementsNamed("description")) {
                description = descString.firstChild().nodeValue.trim().replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n");
                description = htmlStripRegex.replace(description, "");
            }

            for (dateString in file.elementsNamed("date")) {
                var dateData = dateString.firstChild().nodeValue.trim().split(".");
                date = DateTime.fromString(dateData[2] + "-" + dateData[1] + "-" + dateData[0]);
            }

            for (sizeString in file.elementsNamed("size")) {
                size = Math.round( Std.parseInt(sizeString.firstChild().nodeValue.trim()) / 100.0 ) / 10.0;
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
                techinfo: techInfo
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
        } else if ( span.getTotalDays() > 24 ) {
            return span.format("%d days ago");
        } else if ( span.getTotalHours() > 1 ) {
            return span.format("%h hours ago");
        } else if ( span.getTotalMinutes() > 1) {
            return span.format("%i minutes ago");
        } else {
            return "just now";
        }
    }

    public function getMapStatus(mapID:String) {
        if ( Downloader.isModInstalled(mapID) ) {
            return MapStatus.Installed;
        } else if ( Downloader.isMapDownloaded(mapID) ) {
            return MapStatus.Downloaded;
        } else if ( mapID == Downloader.instance.currentMapDownloadID ) {
            return MapStatus.Downloading;
        } else if (UserState.instance.isMapQueued(mapID) ) {
            return MapStatus.Queued;
        } else {
            return MapStatus.NotQueued;
        }
    }
}

typedef MapEntry = {
    var id:String;
    var title:String;
    
    var ?md5sum:String;
    var ?size:Float;
    var ?date:DateTime;
    var ?description:String;
    var ?rating:Float;
    var ?authors:Array<String>;

    var ?techinfo:TechInfo;

    // extra info, diverges away from XML file format
    var ?links:Array<String>;
}

typedef TechInfo = {
    var ?zipbasedir:String;
    var ?commandline:String;
    var ?startmap:Array<String>;
    var ?requirements:Array<String>;
}

enum MapStatus {
    NotQueued;
    Queued;
    Downloading;
    Downloaded;
    Installed;
}