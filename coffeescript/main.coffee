# TODO: Provide page-loookup for adding internal links
# TODO: Provide buttons for common formatting options

# our url will be of form http://apphost.com/store
# article requests will go to http://apphost.com/store/article/name

class Article
    ATTRIBUTE_NAMES = ["name", "content", "parent"]
    
    constructor: (hash) ->
        for own key, value of hash
            this[key] = value

    toAttributes: -> 
        result = {}
        (result[name] = this[name] for name in ATTRIBUTE_NAMES)
        return result
    
    storage: -> this.__proto__.constructor.storage
    
    parent: -> if this.parent_item then this.storage().getLocal(this.parent_item) else undefined
    
    children: -> this.storage().searchLocal (item) => (item.parent_item == this.name)
    
    visit: (callback) -> 
        callback(this)
        child.visit(callback) for child in this.children()
        

Article.depthFirstOrder = ->
    result = []
    article = this.storage.getLocal('title')
    article.dept
    

class MiniWiki
    constructor: (base_url, firstArticle)->
        this.key = firstArticle
        this.baseUrl = base_url
        this.storage = new CachedRESTStorage(this.baseUrl + "/article", "name", Article)
        Article.storage = this.storage
        this.defaultContent = "Nobody has entered anything for this article"
        this.install()
        miniwiki.displayArticle(firstArticle)
        
    storeName: -> this.baseUrl.split("/").pop()
    
    urlFor: (key) ->  this.baseUrl + "/article/" + key
    
    url: ->  this.urlFor(this.key)
    
    keyFromUrl: (url) -> 
        parts = url.split("/")
        parts[parts.length-1]
      
    editField: (fieldName) -> $('#edit_page .field.' + fieldName)

    showField: (fieldName) -> $('#show_page .field.' + fieldName)
    
    eachField: (callback) ->
        $.each ["name", "content"], (index, fieldName) =>
            callback(fieldName)
    
    # Load a new article into the UI      
    load: (newKey, callback) ->
        this.key = newKey if newKey != null
        this.storage.get(this.key, (article) =>
            if article != undefined
                this.eachField (fieldName) =>
                    field = this.editField(fieldName)
                    this.editField(fieldName).val(article[fieldName])
                    val = field.val()
            callback() if callback
        )

    # Update storage from UI
    update: (callback) ->
        name = this.editField('name').val()
        content = this.editField('content').val()
        
        this.storage.put { name: name, content: content }, =>
            links = this.extractInternalLinks(content)
            this.createMissingLinks(links, name)
            callback() if callback
    
    # Create new articles for any internal links in the content
    createMissingLinks: (links, parent) ->
        for link in links
            this.storage.put({ name: link, content: this.defaultContent, parent_item: parent })
            
    # Create handlers for any internal links. The hender should just load the selected page into the UI
    createLocalLinkHandlers: ->
        $('#show_page .wikilink').click (event) ->
            event.preventDefault()
            page = miniwiki.keyFromUrl($(this).attr('href'))
            miniwiki.displayArticle(page)
            
    # Update the display page to reflect what's in the edit fields
    updateDisplay: ->
        name = this.editField('name').val()
        name = "&nbsp;" if /^\s*$/.test(name)
        this.showField('name').html(name)
        content = this.editField('content').val()
        content = "" if content == undefined
        links = this.extractInternalLinks(content)
        content = this.convertInternalLinks(content, links)
        content = convert(content)
        this.showField('content').html(content)
        this.createLocalLinkHandlers()
    
    # extract any wiki internal links of the form [[name]]
    #
    # returns array of page names (["name"])
    extractInternalLinks: (content) ->
        linkTexts = []
        start = 0
        while start < content.length
            startPos = content.indexOf("[[", start)
            if startPos >= 0
              endPos = content.indexOf("]]", startPos)
              if endPos >= 0
                linkTexts.push(content.slice(startPos + 2, endPos))
                start = endPos + 2
              else
                start = content.length
            else
              start = content.length
        linkTexts
    
    convertInternalLinks: (content, links) ->
        for link in links
            textile_link = '<a class="wikilink" href="' + this.urlFor(link) + '">' + link + '</a>'
            content = content.replace("[[" + link + "]]", textile_link)
        content
        
    traverse: (visitor) ->
        roots = this.storage.search (item) => item.parent_item == undefined 
        for root in roots
            this.storage.getLocal(root).visit(visitor)
    
    sync: ->
        $('#show_page .menu .sync').addClass('working')
        this.storage.sync -> $('#show_page .menu .sync').removeClass('working')
        
        return false
        
    showPage: (page) ->
        $(".page").removeClass('current')
        $("#" + page).addClass('current')
        return false
    
    editArticle: ->
        this.showPage('edit_page')
        return false
      
    saveArticle: ->
        this.update()
        this.updateDisplay()
        this.showPage('show_page')
        return false
      
    displayArticle: (key) ->
        this.load key, =>
            this.updateDisplay()
            this.showPage("show_page")
            return false
    
    addItemsToList: (articles) ->
        for article in articles
            $('#browse_page .list').append("<li class='item'><a href='#'>" + article.name + "</a></li>")
            $('#browse_page .list').click (event) =>
                this.displayArticle(event.target.text)

    displayList: (sort) =>
        $('#browse_page .list').empty()
        if sort == "sort_hierarchy"
            articles = []
            this.traverse (article) => articles.push(article)
            this.addItemsToList(articles)
        else
            this.storage.allItems (articles) => this.addItemsToList(articles)
        this.showPage('browse_page')
        return false

    # Set up event handlers
    install: =>
        $('#error').ajaxError (evt, xhr, settings, exception) ->
            console.log("AJAX Error! " + xhr.responseText)
            $(this).text(xhr.responseText)
            $(this).show()
            $(this).fadeOut(5)

        $('.menu .edit').click (event) => this.editArticle()
        $('.menu .browse').click (event) => this.displayList()
        $('.menu .sync').click (event) => this.sync()
        $('.menu .show').click (event) => this.showPage('show_page')
        $('.menu .save').click (event) => this.saveArticle()
        $('.menu .sort').click (event) => this.displayList(event.target.id)

        window.miniwiki = this

MiniWiki.Article = Article
window.MiniWiki = MiniWiki

