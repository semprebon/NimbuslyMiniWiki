url = 'http://localhost:8080/test_main'

store = new window.CachedRESTStorage url, "name"
miniwiki = new window.MiniWiki(url, "Title")

ajax = (options) -> window.testAjax(url, options)

resetWiki = -> 
    window.resetWiki(url + "/article")
    miniwiki.storage.reset()
    console.log("Wiki reset")

module("Miniwiki main")
    
test "Store name should be extracted from url", 1, ->
    equals(miniwiki.storeName(), "test_main")
    
test "load article from storage into UI", 2, ->
    item = { name: "item 1", content: "This is a test" }
    miniwiki.storage.putLocal(item)
    miniwiki.load item, =>
        equals(miniwiki.editField("name").val(), item.name, "should have copied name into name input field")
        equals(miniwiki.editField("content").val(), item.content, "should have copied content into content text area")
        
test "create new stub item from references in content", 3, ->
    resetWiki()
    miniwiki.editField("name").val("new item")
    miniwiki.editField("content").val("This links to [[child item]]")
    miniwiki.update =>
        parent = miniwiki.storage.getLocal("new item")
        equals(parent.content, "This links to [[child item]]")
        child = miniwiki.storage.getLocal("child item")
        equals(child.content, miniwiki.defaultContent)
        equals(child.parent_item, "new item")

test "should be able to get articles children and parent", 4, ->
    resetWiki()
    miniwiki.storage.putLocal({ name: "parent 1", content: "p1" })
    miniwiki.storage.putLocal({ name: "child 1", content: "p1.c1", parent_item: "parent 1" })
    miniwiki.storage.putLocal({ name: "child 2", content: "p1.c2", parent_item: "parent 1" })
    child = miniwiki.storage.getLocal("child 1")
    equals(child.parent().name, "parent 1", "should be able to get parent")
    parent = miniwiki.storage.getLocal("parent 1")
    equals(parent.children().length, 2, "parent should have two children")
    equals(parent.children()[0].name, "child 1", "first child should be child 1")
    equals(parent.children()[1].name, "child 2", "second child should be child 2")
