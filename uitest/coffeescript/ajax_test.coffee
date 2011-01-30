# This just tests that basic server methods are responding correctly

url = window.testing_base_url("/test_ajax/article")

ajax = (options) -> window.testAjax(url, options)
resetWiki = -> window.resetWiki(url)
loggedInUser = ->
    url = window.testing_base_url("/meta/user")
    user = null
    jQuery.ajax({ async: false, type: 'GET', url: url, success: (data) => user = data })
    return user

module "miniwiki ajax api - collective actions"

test "reset wiki deletes all articles in store", 3, ->
     resetWiki()
     data = ajax({ url: "" })
     equals(data.length, 0, "Store should be empty")
     data = ajax({ url: "?summary=true" })
     equals(data.version, 0, "store should be at version 0")
     deepEqual(data.users, [loggedInUser()], "original user should own the store")
     
test "get items starting with a term", 3, ->
    resetWiki()
    ajax({ type: 'PUT', url: '/item1', data: { name: "item 1", content: "testing" } })
    ajax({ type: 'PUT', url: '/item2', data: { name: "item 2", content: "testing 2" } })
    ajax({ type: 'PUT', url: '/nonitem', data: { name: "nonitem", content: "testing 3" } })
    data = ajax({ url: "?term=item" })
    equals(data.length, 2)
    console.log("items starting with item=" + JSON.stringify(data))
    equals(data[0].name, "item 1")
    equals(data[1].name, "item 2")

test "adding user to store", 1, ->
    resetWiki()
    

module "miniwiki ajax api - item actions"

test "putting an item and getting it again", 4, ->
    resetWiki()
    version = ajax({ type: 'PUT', data: { name: "ajax", content: "testing" } })
    equals(version, "1", "version should be 1")
    data = ajax()
    equals(data.name, "ajax", "should save name")
    equals(data.content, "testing", "should save content")
    equals(data.version, 1, " should include version")

test "delete an item then try and get it", 1, ->
    ajax({ type: 'PUT', data: { name: "ajax", content: "testing" } })
    ajax({ type: 'DELETE' })
    ajax({ error: (xhr, status, error) => equals(xhr.status, 404) })

test "put an item thats already there to update data", 2, ->
    ajax({ type: 'PUT', data: { name: 'soap', content: 'yuck'} })
    ajax({ type: 'PUT', data: { content: 'not so good'} })
    data = ajax()
    equals(data.name, 'soap')
    equals(data.content, 'not so good')
    
test "after reset, clear version", 1, ->
    resetWiki()
    version = ajax({ url: "?summary=true" }).version
    equals(version, 0)

test "get all items added since given version", 3, ->
    resetWiki()
    ajax({ type: 'PUT', url: url + '/item1', data: { name: 'item 1', content: 'ok'} })
    ajax({ type: 'PUT', url: url + '/item2', data: { name: "item 2", content: 'no'} })
    newItems = ajax({ url: "?since_version=0" })
    equals(newItems.length, 2, "should return both added items")
    newItems.sort((a,b) -> if a.name < b.name then -1 else if a.name == b.name then 0 else 1)
    equals(newItems[0].name, 'item 1')
    equals(newItems[1].content, 'no')

test "supports parent", 1, ->
    resetWiki()
    ajax({ type: 'PUT', url: url + '/parent', data: { name: 'parent', content: 'ok'} })
    ajax({ type: 'PUT', url: url + '/child', data: { name: "child", content: 'no', parent_item: "parent"} })
    ajax({ type: 'PUT', url: url + '/parent', data: { name: 'parent revised', content: 'ok'} })
    data = ajax({ url: url + '/child' })
    equals(data.parent_item, "parent revised", "should save parent")

module "miniwiki ajax api - meta actions"

test "get all wikis", 1, ->
    resetWiki()
    callback = (data) => 
        ok(data.join('|').indexOf("test_ajax") >= 0, "list of wikis includes test_ajax")
    url = window.testing_base_url("/miniwikis")
    jQuery.ajax({ async: false, type: 'GET', url: url, success: callback })

test "can get user info", 1, ->
    ok(/.*@\w+.\.\w+/.test(loggedInUser().email), "Should return email address")

