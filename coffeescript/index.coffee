window.loadMiniWikis = ->
    jQuery.get "/miniwikis", (data) ->
        $.each data, (index, name) -> 
            $('#wiki_list').append("<li><a href='" + name + "'>" + name + "</a></li>") 