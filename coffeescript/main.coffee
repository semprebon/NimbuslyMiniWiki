# TODO: Provide page-loookup for adding internal links
# TODO: Provide buttons for common formatting options

# our url will be of form http://apphost.com/store
# article requests will go to http://apphost.com/store/article/name

class MiniWiki
    constructor: (firstArticle)->
        this.key = "title"
        this.baseUrl = window.location
        this.storage = new CachedRESTStorage(this.baseUrl + "/article/")
        this.install()
        miniwiki.displayArticle("title")
        

    storeName: => this.baseUrl.split("/").pop
    
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
          
    load: (newKey, callback) ->
        this.key = newKey if newKey != null
        this.storage.get(this.key, (article) =>
            this.eachField (fieldName) =>
              this.editField(fieldName).val(article[fieldName])
            callback() if callback
        )

    update: (callback) ->
        name = this.editField('name').val()
        content = this.editField('content').val()
        
        this.storage.put(this.key, { name: name, content: content }, callback)
        links = this.extractInternalLinks(content)
        this.createMissingLinks(links)
    
    createMissingLinks: (links) ->
        for link in links
            this.storage.put(link, { name: link, content: "say something" })
            
    createLocalLinkHandlers: ->
        $('#show_page .wikilink').click (event) ->
            event.preventDefault()
            page = miniwiki.keyFromUrl($(this).attr('href'))
            miniwiki.displayArticle(page)
            
    updateDisplay: ->
        this.showField('name').html(this.editField('name').val())
        content = this.editField('content').val()
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
        
    showPage: (page) ->
        $(".page").removeClass('current')
        $("#" + page).addClass('current')
    
    editArticle: ->
        this.showPage('edit_page')
      
    saveArticle: ->
        this.update()
        this.updateDisplay()
        this.showPage('show_page')
      
    displayArticle: (key) ->
        miniwiki.load key, ->
            miniwiki.updateDisplay()
            miniwiki.showPage("show_page")
    
    autocompleteSearch: (request, response) =>
        this.storage.search request.term, (articles) ->
            searchResults = (article.name for article in articles)
            response(searchResults)

    # Set up event handlers
    install: =>
        $('#error').ajaxError (evt, xhr, settings, exception) ->
            console.log("AJAX Error! " + xhr.responseText)
            $(this).text(xhr.responseText)


        $('#show_page .menu .edit').click (event) => this.editArticle()
        $('#show_page .menu .search').click (event) => this.showPage('search_page')
        $('#edit_page .menu .save').click (event) => this.saveArticle()
        $('#search_page .menu .show').click (event) => this.showPage('show_page')

        $("#search_page input" ).autocomplete({
            source: this.autocompleteSearch,
            minLength: 2,
            select: (event, ui) -> 
                if ui.item 
                    miniwiki.load(ui.item.value, => window.miniwiki.showPage("show_page"))
        })
        window.miniwiki = this

window.MiniWiki = MiniWiki

