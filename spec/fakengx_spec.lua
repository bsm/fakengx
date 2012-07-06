require 'spec.helper'

context('fakengx', function()

  before(function()
    ngx = fakengx.new()
  end)

  test('instance type', function()
    assert_type(ngx, 'table')
  end)

  test('fresh instances', function()
    ngx.var.something = 1
    local a = fakengx.new()
    assert_tables(a.var, {})
  end)

  test('constants', function()
    assert_equal(ngx.DEBUG, 8)
    assert_equal(ngx.HTTP_GET, 'GET')
    assert_equal(ngx.HTTP_OK, 200)
    assert_equal(ngx.HTTP_BAD_REQUEST, 400)
  end)

  test('static', function()
    assert_equal(ngx.status, 200)
    assert_tables(ngx.var, {})
    assert_tables(ngx.arg, {})
    assert_tables(ngx.header, {})
  end)

  test('internal registries', function()
    assert_equal(ngx._body, "")
    assert_equal(ngx._log, "")
    assert_tables(ngx._captures, { stubs = {} })
  end)

  test('_captures.length()', function()
    assert_equal(ngx._captures:length(), 0)
  end)

  test('_captures.stub()', function()
    local s1 = ngx.location.stub("/subrequest")
    local s2 = ngx.location.stub("/subrequest", { body = "ABC", method = "POST" }, { status = 201 })
    local s3 = ngx.location.stub("/subrequest", { args = { b = 1, a = 2 } }, { body = "OK" })
    assert_equal(ngx._captures:length(), 3)

    local stub
    stub = ngx._captures.stubs[1]
    assert_equal(stub, s1)
    assert_equal(stub.uri, "/subrequest")
    assert_tables(stub.opts, { })
    assert_tables(stub.res, { status = 200, headers = {}, body = "" })

    stub = ngx._captures.stubs[2]
    assert_equal(stub, s2)
    assert_equal(stub.uri, "/subrequest")
    assert_tables(stub.opts, { body = "ABC", method = "POST" })
    assert_tables(stub.res, { status = 201, headers = {}, body = "" })

    stub = ngx._captures.stubs[3]
    assert_equal(stub, s3)
    assert_equal(stub.uri, "/subrequest")
    assert_tables(stub.opts, { args = "a=2&b=1" })
    assert_tables(stub.res, { status = 200, headers = {}, body = "OK" })
  end)

  test('_captures.find()', function()
    local s0 = ngx.location.stub("/subrequest", { }, { status = 200 })
    local s1 = ngx.location.stub("/subrequest", { method = "GET" }, { status = 200 })
    local s2 = ngx.location.stub("/subrequest", { body = "~>A%a+C", method = "POST" }, { status = 201, headers = { Location = "http://host/resource/1" } })
    local s3 = ngx.location.stub("/subrequest", { args = { b = 1, a = 2 } }, { body = "OK" })
    local s4 = ngx.location.stub("/subrequest", { body = (function(v) return v == "HI" end) }, { body = "OK" })

    assert_nil(ngx._captures:find("/not-registered", {}))
    assert_nil(ngx._captures:find("/not-registered"))

    assert_tables(ngx._captures:find("/subrequest"), s1)
    assert_tables(ngx._captures:find("/subrequest", { method = "GET" }), s1)
    assert_tables(ngx._captures:find("/subrequest", { method = "POST", body = "ABC" }), s2)
    assert_tables(ngx._captures:find("/subrequest", { body = "ABC" }), s1)
    assert_tables(ngx._captures:find("/subrequest", { args = "a=2&b=1" }), s3)
    assert_tables(ngx._captures:find("/subrequest", { args = { a = 2, b = 1 } }), s3)
    assert_tables(ngx._captures:find("/subrequest", { args = "b=1&a=1" }), s1)
    assert_tables(ngx._captures:find("/subrequest", { method = "POST" }), s0)
    assert_tables(ngx._captures:find("/subrequest", { body = "HI" }), s4)
  end)

  test('print()', function()
    ngx.print("string")
    assert_equal(ngx._body, "string")
  end)

  test('say()', function()
    ngx.say("string")
    assert_equal(ngx._body, "string\n")
  end)

  test('log()', function()
    ngx.log(ngx.NOTICE, "string")
    assert_equal(ngx._log, "LOG(6): string\n")
  end)

  test('time()', function()
    assert_type(ngx.time(), 'number')
    local t = os.time()
    assert_equal(ngx.time(), t)
    while os.time() - t == 0 do end -- wait for next second
    assert_equal(ngx.time(), t)     -- ensure cached value is used
  end)

  test('update_time()', function()
    local t = os.time()
    local t1 = ngx.time()
    local n1 = ngx.now()
    while os.time() - t == 0 do end -- wait for next second
    assert_equal(ngx.time(), t1)    -- until ngx.update_time() is called uses cached value
    assert_equal(ngx.now(), n1)
    ngx.update_time()
    assert_greater_than(ngx.time(), t1)
    assert_greater_than(ngx.now(), n1)
  end)

  test('now()', function()
    assert_type(ngx.now(), 'number')
    assert(ngx.now() >= os.time())
    assert(ngx.now() <= (os.time() + 1))
  end)

  test('exit()', function()
    assert_equal(ngx.status, 200)
    assert_nil(ngx._exit)

    ngx.exit(ngx.HTTP_BAD_REQUEST)
    assert_equal(ngx.status, 400)
    assert_equal(ngx._exit, 400)

    ngx.exit(ngx.HTTP_OK)
    assert_equal(ngx.status, 400)
    assert_equal(ngx._exit, 200)
  end)

  test('escape_uri()', function()
    assert_equal(ngx.escape_uri("here [ & ] now"), "here+%5B+%26+%5D+now")
  end)

  test('unescape_uri()', function()
    assert_equal(ngx.unescape_uri("here+%5B+%26+%5D+now"), "here [ & ] now")
  end)

  test('encode_args()', function()
    assert_equal(ngx.encode_args({foo = 3, ["b r"] = "hello world"}), "b%20r=hello%20world&foo=3")
    assert_equal(ngx.encode_args({["b r"] = "hello world", foo = 3}), "b%20r=hello%20world&foo=3")
  end)

  test('crc32_short()', function()
    assert_type(ngx.crc32_short("abc"), 'number')
    assert_equal(ngx.crc32_short("abc"), 891568578)
    assert_equal(ngx.crc32_short("def"), 214229345)
  end)

  test('location.capture()', function()
    local s1 = ngx.location.stub("/stubbed", {}, { body = "OK" })

    assert_error(function() ngx.location.capture("/not-stubbed") end)
    assert_not_error(function() ngx.location.capture("/stubbed") end)
    assert_equal(#s1.calls, 1)

    assert_tables(ngx.location.capture("/stubbed"), { status = 200, headers = {}, body = "OK" })
    assert_equal(#s1.calls, 2)
  end)

  test('location.capture_multi()', function()
    local s1 = ngx.location.stub("/stubbed", {}, { body = "OK" })
    local s2 = ngx.location.stub("/stubbed2", {}, { body = "OK" })

    assert_not_error(function() ngx.location.capture_multi({ { "/stubbed" }, { "/stubbed2"} }) end)
    assert_equal(#s1.calls, 1)
    assert_equal(#s2.calls, 1)

    local r1, r2
    r1, r2 = ngx.location.capture_multi({ { "/stubbed" }, { "/stubbed2"} })
    assert_equal(r1.body, 'OK')
    assert_equal(r2.body, 'OK')
  end)

  test('req.read_body()', function()
    assert_nil(ngx.req.read_body())
  end)

  test('shared.get()', function()
    ngx.shared.shared_key = 123
    assert_equal(ngx.shared:get('shared_key'), 123)
  end)

  test('shared.set()', function()
    ngx.shared:set('some_key', 456)
    assert_equal(ngx.shared.some_key, 456)
    assert_equal(ngx.shared:get('some_key'), 456)
  end)

end)