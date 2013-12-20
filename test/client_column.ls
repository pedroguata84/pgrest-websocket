should = (require \chai).should!
assert = (require \chai).assert
{mk-pgrest-fortest} = require \./testlib
pgclient = require "../client/ref" .Ref

require! \express
require! pgrest

socket-url = 'http://localhost:8080'

var _plx, plx, app, client, server
describe 'Websocket Client on Column' ->
  this.timeout 10000ms
  beforeEach (done) ->
    _plx <- mk-pgrest-fortest!
    plx := _plx
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    CREATE TABLE foo (
      _id int,
      bar text
    );
    DROP TABLE IF EXISTS bar;
    CREATE TABLE bar (
      _id int,
      info text
    );
    INSERT INTO foo (_id, bar) values(1, 'test');
    INSERT INTO foo (_id, bar) values(2, 'test2');
    INSERT INTO bar (_id, info) values(1, 't1');
    INSERT INTO bar (_id, info) values(2, 't2');
    """

    {mount-default,with-prefix} = pgrest.routes!
    {mount-socket} = require \../lib/socket
    app := express!
    app.use express.cookieParser!
    app.use express.json!
    server := require \http .createServer app
    io = require \socket.io .listen server, { log: false}
    server.listen 8080

    cols <- mount-socket plx, null, io
    client := new pgclient "#socket-url/foo/1/bar", { force: true }

    done!
  afterEach (done) ->
    <- plx.query """
    DROP TABLE IF EXISTS foo;
    DROP TABLE IF EXISTS bar;
    """
    client.disconnect!
    done!
  describe 'Ref is on a column', ->
    describe "Reference", -> ``it``
      .. 'should have correct ref type', (done) ->
        client.refType.should.eq \column
        done!
    describe "Reading values", -> ``it``
      .. 'should be able to get specified column via \'value\' event', (done) ->
        client.on \value ->
          it.should.eq "test"
          done!
    describe "Setting values", -> ``it``
      .. '.set should replace the column', (done) ->
        client.set "replaced"
        client.on \value, ->
          it.should.eq \replaced
          done!
    describe "Updating value", -> ``it``
      .. '.update should replace the column', (done) ->
        client.set "replaced"
        client.on \value, ->
          it.should.eq \replaced
          done!
    describe "Removing values", -> ``it``
      .. '.remove should set the column to undefined', (done) ->
        client.remove!
        client.on \value, ->
          assert.isNull it
          done!
      .. '.remove can provide a callback to know when completed', (done) ->
        <- client.remove
        done!
    describe "Removing listener", -> ``it``
      .. '.off should remove all listener on a specify event', (done) ->
        client.on \value, ->
          client.socket.listeners(\foo:child_changed).length.should.eq 1
          client.off \value
          client.socket.listeners(\foo:child_changed).length.should.eq 0
          done!
      .. '.off can remove specified listener on a event', (done) ->
        cb = ->
          client.socket.listeners(\foo:child_changed).length.should.eq 1
          client.off \value, cb
          client.socket.listeners(\foo:child_changed).length.should.eq 0
          done!
        client.on \value, cb
      .. 'offed trigger should not receive futher events', (done) ->
        cb = ->
          # this should only triggered once
          client.socket.listeners(\foo:child_changed).length.should.eq 1
          client.off \value, cb
          client.socket.listeners(\foo:child_changed).length.should.eq 0
          <- client.set "replaced"
          done!
        client.on \value, cb
    describe "Once callback", -> ``it``
      .. 'should return referenced column', (done) ->
        client.once \value, ->
          it.should.eq \test
          done!
      .. '.once callback should only fire once', (done) ->
        client.once \value, ->
          client.socket.listeners(\foo:child_changed).length.should.eq 0
          done!
    describe "toString", -> ``it``
      .. ".toString should return absolute url", (done) ->
        client.toString!should.eq "http://localhost:8080/foo/1/bar"
        done!
    describe "root", -> ``it``
      .. ".root should return host url", (done) ->
        client.root!should.eq "http://localhost:8080"
        done!
    describe "name", -> ``it``
      .. ".name should return table name", (done) ->
        client.name!.should.eq \bar
        done!
    var parent
    describe "parent", -> ``it``
      beforeEach (done) ->
        parent := client.parent!
        done!
      afterEach (done) ->
        parent.disconnect!
        done!
      .. ".parent should return entry", (done) ->
        parent.refType.should.eq \entry
        parent.on \value ->
          done!
