$(document).ready ->

    module("Miniwiki main")
    
    test "a basic test example", ->
        ok( true, "this test is fine" )
        value = "hello"
        equals( "hello", value, "We expect value to be hello" )

    

    test "first test within module", ->
        ok( true, "all pass" )

    test "second test within module", ->
        ok( true, "all pass" )

    module("Module B")

    test "some other test", ->
        expect(2)
        equals( true, false, "failing test" )
        equals( true, true, "passing test" )
