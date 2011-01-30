url = window.testing_base_url("/test_main")

store = new window.CachedRESTStorage url, "name"
miniwiki = new window.MiniWiki(url, "Index")

ajax = (options) -> window.testAjax(url, options)

resetWiki = -> 
    window.resetWiki(url + "/article")
    miniwiki.storage.reset()
    console.log("Wiki reset")

module("Miniwiki main")

test "Store name should be extracted from url", 1, ->
    equals(miniwiki.storeName(), "test_main")
    
test "Should be able to get relevent fields from item", 3, ->
    item = new MiniWiki.Article({ name: "item", content: "testing", parent: "item2"}).toAttributes()
    equals(item.name, "item")
    equals(item.content, "testing")
    equals(item.parent, "item2")
    
    
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

test "tree traversal", 1, ->
    resetWiki()
    miniwiki.storage.putLocal({ name: "root", content: "root node" })
    miniwiki.storage.putLocal({ name: "parent", content: "testing 1", parent_item: "root" })
    miniwiki.storage.putLocal({ name: "parent 2", content: "testing 2", parent_item: "root" })
    miniwiki.storage.putLocal({ name: "root 2", content: "testing 2" })
    miniwiki.storage.putLocal({ name: "child 3", content: "testing 2", parent_item: "parent 2" })
    miniwiki.storage.putLocal({ name: "child 1", content: "not good", parent_item: "parent" })
    miniwiki.storage.putLocal({ name: "child 2", content: "testing 2", parent_item: "parent" })
    list = []
    miniwiki.traverse (item) => list.push(item.name)
    deepEqual(['root', 'parent', 'child 1', 'child 2', 'parent 2', 'child 3', 'root 2'], list, 
        "items should be vistied in order")
