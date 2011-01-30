window.testing_base_url = (test) ->
    window.location.protocol + "//" + window.location.host + test
    

DEFAULT_OPTIONS = { async: false, type: 'GET' }

window.testAjax = (baseUrl, options) ->
    result = null
    callback = (data) -> 
        result = data
    errorCallback = (xhr, status) ->
        result = status
    actualOptions = jQuery.extend({ success: callback, error: errorCallback }, DEFAULT_OPTIONS, options)
    if actualOptions.url || actualOptions.url == ""
        actualOptions.url = baseUrl + actualOptions.url
    else
         actualOptions.url = baseUrl + "/ajax_item"
    jQuery.ajax(actualOptions)
    return result

window.resetWiki = (baseUrl) -> 
    window.testAjax(baseUrl, { type: 'PUT', url: "" })
    window.testAjax(baseUrl, { type: 'DELETE', url: "?confirm=true&keep_store=true" })

