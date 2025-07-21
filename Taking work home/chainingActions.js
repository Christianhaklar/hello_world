//okay, so the idea is to use whatever copilot suggested, just make it more my style
//this probably needs to be slightly updated, but at least it feels better to look at

function runScriptChain(timer, scripts) {

    let stopFlag = false;

    //try it with this?
    function stopChain() {
        stopFlag = true;
    }

    for (let i = 0; i < scripts.length; i++) {
        //if the script is null, or the stopflag is set, we abort
        if (!scripts[i] || stopFlag) { return null; }
        try {
            //if not, we execute whatever is in the array element
            var tid = setInterval(() => {
                //but we also need to pass the function here as well, but only if it has a parameter
                if (scripts[i].length > 0) {
                    //execute with a parameter
                    scripts[i](stopChain);
                }
                else {
                    //execute without parameter
                    scripts[i]();
                }

                pageReady = $jQuery('something');
                if (pageReady) {
                    clearInterval(tid);
                    //this is where you would do the thing, but since we are running a chain, we don't need to
                }
            }, timer);
        }
        catch (error) {
            //if we got an error, stop execution
            console.log('Stopped script chain a step ' + i + 'error: ' + error);
            return null;
        }
    }
}

//now try running it
let scripts = [
    () => {
        $form.executeWebService('webservice1');
    },
    //we need to actually pass the function, so it can be called
    (stopChain) => {
        if ($form.getValue('fieldName').match('/Err/') != null) {
            stopChain();
        }
    },
    () => {
        $form.executeWebService('webservice2')
    }
]