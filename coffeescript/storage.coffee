# The storage. All items are stored locally, and synced with the database as needed

# TODO: Storage should prefetch all relevent records it needs from server (i..e, since it last synced)
# TODO: Storage should detect when offline; and periodically check if online when offline
class CachedRESTStorage

    # item states
    CLEAN = 'clean'
    DIRTY = 'dirty'
    DELETED = 'deleted'

    # Create a new Cached RESTful storage object
    #
    # @param {string} url  base url for the backing web service
    # @param {string} keyField  field of stored items to use as a key field
    constructor: (url, keyField) ->
        this.url = url
        this.keyField = keyField
        this.log("cached rest storage created for " + this.url, "(no key)")
        $('#ajax_error').ajaxError((e, xhr, settings, exception) =>
            $(this).html(xhr.responseText)
        )

    # Get item from local storage
    #
    # @param {string} key  The key value for the item to get
    # @return item, or undefined if item not found or has been deleted
    getLocal: (key) ->
        this.log("fetching local data", key)
        raw = localStorage[this.urlFor(key)]
        return undefined if raw == undefined
        meta = JSON.parse(raw)
        return undefined if meta.state == DELETED
        return meta.data
    
    # Get item from remote storage and put it into local storage
    #
    # @param {string} key
    # @param {function(item)} callback  function to call after item is fetched
    # @param {function(xhr,status)} errorCallback  function to call if an AJAX error occurs
    getRemote: (key, callback, errorCallback) ->
        this.log('fetching remote data...', key)
        item = $.ajax { 
            url: this.urlFor(key), 
            dataType: 'json',
            success: (item) => this.putLocal(item); callback(item),
            error: (xhr, status) => errorCallback(xhr, status)
        }
        
    # Get item from local storage, after perhaps syncing with remote storage
    #
    # @param {string} key  The key value for the item to get
    # @param {function(item)} callback  function to call after item is fetched
    # @param {function(xhr,status)} errorCallback  function to call if an AJAX error occurs
    get: (key, callback, errorCallback) ->
        # optionall sync here if offline
        item = this.getLocal(key)
        callback(item)

    # Puts or replaces an item in local storage, marking it for later remote updating
    #
    # @param {object} data  Item to store
    # @param {string} state  optional state to set on the object, used internaly  
    putLocal: (data, state) ->
        state = DIRTY if state == undefined
        localStorage[this.urlFor(data)] = JSON.stringify({ state: state, data: data })

    # Puts or replaces an item on the remote server
    #
    # @param {object} data  Item to store
    # @param {function()} callback  function to call after item is put
    # @param {function(xhr,status)} errorCallback  function to call if an AJAX error occurs
    putRemote: (data, callback, errorCallback) ->
        $.ajax { 
            type: 'PUT', url: this.urlFor(data), data: data, 
            success: (data) => this.log("remote data saved", data); callback(data) if callback,
            error: => this.log("error", data); errorCallback() if errorCallback
        }
        
    # Puts or replaces an item, possibly also sending it to the remote server
    #
    # @param {object} data  Item to store
    # @param {function()} callback  function to call after item is put
    # @param {function(xhr,status)} errorCallback  function to call if an AJAX error occurs
    put: (data, callback, errorCallback) ->
        this.putLocal(data)
        if this.syncing()
            this.log("storing remote data...", data)
            this.putRemote(data, callback, errorCallback)
        else
            callback()

    # Mark an item as deleted in local storage, and queue it to be deleted remotely
    markDelete: (keyOrItem) ->
        this.log("deleting local data", keyOrItem)
        this.state(keyOrItem, DELETED)

    deleteLocal: (name) ->
        localStorage.removeItem(this.urlFor(name))

    deleteRemote: (name, callback) ->
        $.ajax {
            type: 'DELETE', url: this.urlFor(name),
            success: => this.log("remote data deleted", name); callback() if callback
        }
        
    delete: (keyOrItem, callback) ->
        this.markDelete(keyOrItem)
    
    DEFAULT_CONFIG = { state: CLEAN, lastRemoteVersion: 0 }
    
    configureOption: (name, value) ->
        data = localStorage[@url] || DEFAULT_CONFIG
        if value
            data[name] = value
            localStorage[@url] = data
        return data[name]
        
    version: (newVersion) -> this.configureOption('version', newVersion)
    
    syncing: (flag) -> this.configureOption('syncing', flag)
         
    unsyncedItems: ->
        items = []
        for name in this.allKeys()
            if this.state(name) == DIRTY
                items[items.length] = this.getLocal(name)
            else if this.state(name) == DELETED
                items[items.length] = name
        return items
        
    itemMetadata: (keyOrItem, metatag, value) ->
        url = this.urlFor(keyOrItem)
        raw = localStorage[url]
        return undefined if raw == undefined
        meta = JSON.parse(raw)
        if value != undefined
            meta[metatag] = value
            localStorage[url] = JSON.stringify(meta)
        meta[metatag]

    state: (name, value) -> this.itemMetadata(name, "state", value)
    
    synced: (name, value) -> 
        state = this.state(name, value)
        state == CLEAN || state == undefined
        
    syncItem: (item, callback) ->
        if (typeof item) == "string"
            this.deleteRemote item, =>
                this.deleteLocal(item)
                callback()
        else
            this.putRemote item, =>
                this.state(item, CLEAN)
                callback()
        
    # Remove the first item in items and send it to remote; processing the remaining list
    # in the callback
    sendNextItem: (items, callback) ->
        if items.length == 0
            callback()
        else
            item = items[0]
            items = items.slice(1, items.length-1)
            this.syncItem(item, => this.sendNextItem(items, callback))
                        
    sendLocallyModifiedItems: (callback) ->
        items = this.unsyncedItems()
        this.sendNextItem(items, callback) 
        
    # TODO: save last sent remote version and use it when resending
    sync: (callback) ->
        this.log("syncing remote data...", "")
        this.sendLocallyModifiedItems =>
            this.log("getting remote changes", "")
            $.ajax { type: 'GET', url: @url + "?since_version=0", dataType: "json", success: (items) =>
                this.log("got " + items.length + " items", "")
                for item in items
                    this.log("syncing " + JSON.stringify(item))
                    if item.deleted
                        this.deleteLocal(item)
                    else
                        this.putLocal(item, CLEAN)
                this.log("synced.", "")
                callback()
            }

    # Return an array of all keys that start with the specified prefix
    keysWithPrefix: (keyPrefix) ->
        keys = []
        urlPrefix = this.urlFor(keyPrefix)
        for index in [0..localStorage.length-1]
            url = localStorage.key(index)
            keys[keys.length] = this.keyForUrl(url) if url.substr(0, urlPrefix.length) == urlPrefix
        return keys
    
    search: (prefix, callback) ->
        this.log("searching local keys", prefix + "*")
        keys = this.keysWithPrefix(prefix)
        articles = (this.getLocal(key) for key in keys)
        callback(articles)
    
    allKeys: -> this.keysWithPrefix("")
        
    # Remove all local data for this store
    reset: -> 
        (this.deleteLocal(key) for key in this.allKeys())
        this.version(0)
    
    size: -> this.allKeys().length
        
    urlFor: (keyOrItem) ->  @url + "/" + this.keyFor(keyOrItem)
    
    keyFor: (keyOrItem) -> if (typeof keyOrItem) == "object" then keyOrItem[this.keyField] else keyOrItem

    keyForUrl: (url) -> url.substr(@url.length + 1)

    log: (message, keyOrItem) ->
        console.info(message + ": " + this.keyFor(keyOrItem))

window.CachedRESTStorage = CachedRESTStorage