package;

import sys.Http;

/** very basic modification of sys.Http to let us read the BytesOutput and measure download progress **/
// TODO: must manually merge in any changes to request() from https://github.com/HaxeFoundation/haxe/blob/development/std/sys/Http.hx
class HttpQuakey extends Http {

    /** the current byte stream in memory from the HTTP download, check its progress with currentOutput.length ? **/
    public var currentOutput: haxe.io.BytesOutput;

    public override function request(?post:Bool) {
		currentOutput = new haxe.io.BytesOutput(); // this is all I did lol
        var output = currentOutput;
		var old = onError;
		var err = false;
		onError = function(e) {
			responseBytes = output.getBytes();
			err = true;
			// Resetting back onError before calling it allows for a second "retry" request to be sent without onError being wrapped twice
			onError = old;
			onError(e);
		}
		post = post || postBytes != null || postData != null;
		customRequest(post, output);
		if (!err) {
			success(output.getBytes());
		}
	}
}