{test, prepare, Promise, getTestID, after} = require "snapy"
try
  Lea = require "leajs-server/src/lea"
catch
  Lea = require "leajs-server"
http = require "http"
{writeFile, unlink, createWriteStream} = require "fs-extra"
require "../src/plugin"
port = => 8081 + getTestID()

request = (path = "/", headers = {}) =>
  filter: "
    headers
    statusCode
    -headers.date
    body
    -headers.last-modified
    trailers
    "
  stream: "":"body"
  promise: new Promise (resolve, reject) =>
    http.get {
      hostname: "localhost"
      port: port()
      agent: false 
      path: path
      headers: headers
      }, resolve
    .on "error", reject
  plain: true

prepare (state, cleanUp) =>
  lea = await Lea
    config: Object.assign (state or {}), {
      listen:
        port:port()
      disablePlugins: ["leajs-cache"]
      plugins: ["./src/plugin"]
      cache: Math.pow(2,16)
      cacheFile: false
      }
  cleanUp => lea.close()
  return state.files
  
test {files:{"/":"./test/file1"}}, (snap, files, cleanUp) =>
  # simple gzip
  filename = files["/"]
  await writeFile filename, "file1"
  cleanUp => unlink filename
  snap request "/"
  .then ({value}) =>
    snap request "/", "if-none-match":value.trailers.etag
    snap request "/"