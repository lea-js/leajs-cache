
# leajs-cache

Plugin of [leajs](https://github.com/lea-js/leajs-server).

Handles caching of resources.

## leajs.config

```js
module.exports = {

  // …

  // Maximum filesize to cache
  // Default: if inProduction then 65536 else false
  cache: null, // [Number, Boolean]

  // default file to save cache on exit. Set False to disable.
  // types: [String, Boolean]
  cacheFile: "./.leajs-cache.json",

  // …

}
```

## License
Copyright (c) 2018 Paul Pflugradt
Licensed under the MIT license.